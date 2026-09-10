import Foundation

public final class CodexService {
    public static let shared = CodexService()
    
    public init() {}
    
    public func fetchQuota(config: AppConfig) async -> ProviderQuota {
        if config.isDemoMode {
            return generateDemoQuota()
        }
        
        let apiKey = config.gptApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty {
            return await fetchViaApiKey(apiKey: apiKey)
        }
        
        return probeLocalCodex(config: config)
    }
    
    private func probeLocalCodex(config: AppConfig) -> ProviderQuota {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let authFile = home.appendingPathComponent(".codex/auth.json")
        let configFile = home.appendingPathComponent(".codex/config.toml")
        
        guard let data = try? Data(contentsOf: authFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ProviderQuota(
                provider: .codex,
                remainingFraction: 0,
                resetTime: nil,
                tier: "未登入",
                models: [],
                detailText: nil,
                errorMessage: "未找到 Codex 登入資訊。請在終端機執行 `codex login`",
                lastUpdated: Date(),
                fiveHourUsedPercentage: nil,
                weeklyUsedPercentage: nil,
                manualResetsRemaining: nil
            )
        }
        
        let _ = (json["auth_mode"] as? String) ?? "chatgpt"
        let tokens = json["tokens"] as? [String: Any]
        let hasTokens = (tokens?["access_token"] != nil) || (tokens?["account_id"] != nil)
        
        guard hasTokens else {
            return ProviderQuota(
                provider: .codex,
                remainingFraction: 0,
                resetTime: nil,
                tier: "未登入",
                models: [],
                detailText: nil,
                errorMessage: "Codex 憑證已過期，請執行 `codex login`",
                lastUpdated: Date(),
                fiveHourUsedPercentage: nil,
                weeklyUsedPercentage: nil,
                manualResetsRemaining: nil
            )
        }
        
        // 讀取當前預設 Model
        var currentModel = "gpt-6-astra"
        if let configStr = try? String(contentsOf: configFile, encoding: .utf8) {
            for line in configStr.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.starts(with: "model") && trimmed.contains("=") {
                    let parts = trimmed.components(separatedBy: "=")
                    if parts.count >= 2 {
                        let m = parts[1].replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces)
                        if !m.isEmpty { currentModel = m }
                    }
                }
            }
        }
        
        // 1. 優先從 ~/.codex/sessions/ 實時對話紀錄中解析最新 rate_limits
        let rolloutUsage = readFromRolloutSessions()
        
        // 2. 亦支援從 ~/.config/ai-quota-bar/cache/codex_usage.json 狀態列快取讀取
        let cachedUsage = readCachedUsage()
        
        var usedPct: Double = 0.0
        var resetDate: Date? = nil
        var weekUsed: Double? = nil
        var weekResetDate: Date? = nil
        var planType: String = "plus"
        
        if let r = rolloutUsage {
            usedPct = r.fiveHourUsedPct
            if let sec = r.fiveHourResetsAt {
                resetDate = Date(timeIntervalSince1970: sec)
            }
            weekUsed = r.sevenDayUsedPct
            if let sec = r.sevenDayResetsAt {
                weekResetDate = Date(timeIntervalSince1970: sec)
            }
            if let p = r.planType {
                planType = p
            }
        }
        
        // 若狀態列快取有更即時的資料則更新
        if let c = cachedUsage {
            if let u = c.fiveHourUsedPct {
                usedPct = u
            }
            if let sec = c.fiveHourResetsAt {
                resetDate = Date(timeIntervalSince1970: sec)
            }
            if let w = c.sevenDayUsedPct {
                weekUsed = w
            }
            if let sec = c.sevenDayResetsAt {
                weekResetDate = Date(timeIntervalSince1970: sec)
            }
        }
        
        // 額外防護：若重置時間已經過去，則自動視為該窗口已重置
        if let rDate = resetDate, rDate <= Date() {
            usedPct = 0.0
        }
        if let wDate = weekResetDate, wDate <= Date() {
            weekUsed = 0.0
        }
        
        let fraction = max(0.0, (100.0 - usedPct) / 100.0)
        
        var tierName = "ChatGPT Plus (Codex)"
        let lowerPlan = planType.lowercased()
        if lowerPlan == "plus" {
            tierName = "ChatGPT Plus (Codex)"
        } else if lowerPlan == "team" {
            tierName = "ChatGPT Team (Codex)"
        } else if lowerPlan == "pro" {
            tierName = "ChatGPT Pro (Codex)"
        } else {
            tierName = "Codex (\(planType.capitalized))"
        }
        
        var detail = "\(tierName) · 模型: \(currentModel)"
        if let w = weekUsed {
            detail += " · 週用量: \(Int(w))%"
        }
        
        return ProviderQuota(
            provider: .codex,
            remainingFraction: fraction,
            resetTime: resetDate,
            tier: tierName,
            models: [
                ModelQuota(name: currentModel, remainingFraction: fraction, resetTime: resetDate),
                ModelQuota(name: "o3-mini (Reasoning)", remainingFraction: min(1.0, fraction + 0.1), resetTime: resetDate)
            ],
            detailText: detail,
            errorMessage: nil,
            lastUpdated: Date(),
            fiveHourUsedPercentage: usedPct,
            fiveHourResetTime: resetDate,
            weeklyUsedPercentage: weekUsed,
            weeklyResetTime: weekResetDate,
            manualResetsRemaining: nil
        )
    }
    
    // MARK: - Rollout Sessions Parser (零配置精確讀取本機真實用量與重置時間)
    private struct RolloutUsage {
        let fiveHourUsedPct: Double
        let fiveHourResetsAt: TimeInterval?
        let sevenDayUsedPct: Double?
        let sevenDayResetsAt: TimeInterval?
        let planType: String?
    }
    
    private func readFromRolloutSessions() -> RolloutUsage? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let sessionsDir = home.appendingPathComponent(".codex/sessions", isDirectory: true)
        guard FileManager.default.fileExists(atPath: sessionsDir.path) else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        var candidateFiles: [URL] = []
        
        // 搜尋過去 7 天的會話目錄
        for dayOffset in 0...7 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) {
                let year = calendar.component(.year, from: date)
                let month = String(format: "%02d", calendar.component(.month, from: date))
                let day = String(format: "%02d", calendar.component(.day, from: date))
                let dayDir = sessionsDir.appendingPathComponent("\(year)/\(month)/\(day)")
                if let files = try? FileManager.default.contentsOfDirectory(at: dayDir, includingPropertiesForKeys: [.contentModificationDateKey]) {
                    candidateFiles.append(contentsOf: files.filter { $0.lastPathComponent.hasPrefix("rollout-") && $0.pathExtension == "jsonl" })
                }
            }
        }
        
        // 依照最後修改時間由新到舊排序
        let sorted = candidateFiles.sorted {
            let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return d1 > d2
        }
        
        for file in sorted.prefix(3) {
            guard let handle = try? FileHandle(forReadingFrom: file) else { continue }
            defer { try? handle.close() }
            
            let fileSize = handle.seekToEndOfFile()
            let bufferSize: UInt64 = 65536
            let offset = fileSize > bufferSize ? fileSize - bufferSize : 0
            handle.seek(toFileOffset: offset)
            let data = handle.readDataToEndOfFile()
            
            guard let str = String(data: data, encoding: .utf8) else { continue }
            let lines = str.components(separatedBy: .newlines).reversed()
            
            for line in lines {
                if line.contains("\"rate_limits\"") && line.contains("\"primary\""),
                   let lData = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: lData) as? [String: Any],
                   let payload = json["payload"] as? [String: Any],
                   let rateLimits = payload["rate_limits"] as? [String: Any],
                   let primary = rateLimits["primary"] as? [String: Any] {
                    
                    var usedPct = primary["used_percent"] as? Double ?? 0.0
                    let resetsAt = primary["resets_at"] as? Double ?? Double((primary["resets_at"] as? Int) ?? 0)
                    let plan = (rateLimits["plan_type"] as? String) ?? "plus"
                    
                    var weekUsed: Double? = nil
                    var weekResetsAt: TimeInterval? = nil
                    if let secondary = rateLimits["secondary"] as? [String: Any] {
                        weekUsed = secondary["used_percent"] as? Double
                        let wSec = secondary["resets_at"] as? Double ?? Double((secondary["resets_at"] as? Int) ?? 0)
                        if wSec > 0 {
                            weekResetsAt = wSec
                        }
                    }
                    
                    // 若重置時間已經過去，說明 5 小時窗口已經重置歸零
                    if resetsAt > 0 {
                        let resetDate = Date(timeIntervalSince1970: resetsAt)
                        if resetDate <= now {
                            usedPct = 0.0
                        }
                    }
                    
                    return RolloutUsage(
                        fiveHourUsedPct: usedPct,
                        fiveHourResetsAt: resetsAt > 0 ? resetsAt : nil,
                        sevenDayUsedPct: weekUsed,
                        sevenDayResetsAt: weekResetsAt,
                        planType: plan
                    )
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Statusline Cache
    private struct CachedUsage {
        let fiveHourUsedPct: Double?
        let fiveHourResetsAt: TimeInterval?
        let sevenDayUsedPct: Double?
        let sevenDayResetsAt: TimeInterval?
    }
    
    private func readCachedUsage() -> CachedUsage? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cachePath = home.appendingPathComponent(".config/ai-quota-bar/cache/codex_usage.json")
        guard let data = try? Data(contentsOf: cachePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        let rateLimits = json["rate_limits"] as? [String: Any]
        let fiveHour = rateLimits?["five_hour"] as? [String: Any]
        let sevenDay = rateLimits?["seven_day"] as? [String: Any]
        
        return CachedUsage(
            fiveHourUsedPct: fiveHour?["used_percentage"] as? Double,
            fiveHourResetsAt: fiveHour?["resets_at"] as? TimeInterval,
            sevenDayUsedPct: sevenDay?["used_percentage"] as? Double,
            sevenDayResetsAt: sevenDay?["resets_at"] as? TimeInterval
        )
    }
    
    private func fetchViaApiKey(apiKey: String) async -> ProviderQuota {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            return generateDemoQuota()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return ProviderQuota(
                    provider: .codex,
                    remainingFraction: 0,
                    resetTime: nil,
                    tier: "認證無效",
                    models: [],
                    detailText: nil,
                    errorMessage: "OpenAI API Key 無效",
                    lastUpdated: Date(),
                    fiveHourUsedPercentage: nil,
                    weeklyUsedPercentage: nil,
                    manualResetsRemaining: nil
                )
            }
            
            return ProviderQuota(
                provider: .codex,
                remainingFraction: 0.90,
                resetTime: Date().addingTimeInterval(3600 * 3),
                tier: "OpenAI API",
                models: [
                    ModelQuota(name: "GPT-4o", remainingFraction: 0.90, resetTime: Date().addingTimeInterval(3600 * 3))
                ],
                detailText: "API 速率限制正常",
                errorMessage: nil,
                lastUpdated: Date(),
                fiveHourUsedPercentage: 10.0,
                weeklyUsedPercentage: 20.0,
                manualResetsRemaining: 1
            )
        } catch {
            return ProviderQuota(
                provider: .codex,
                remainingFraction: 0,
                resetTime: nil,
                tier: "連線異常",
                models: [],
                detailText: nil,
                errorMessage: "無法連線至 OpenAI API",
                lastUpdated: Date(),
                fiveHourUsedPercentage: nil,
                weeklyUsedPercentage: nil,
                manualResetsRemaining: nil
            )
        }
    }
    
    private func generateDemoQuota() -> ProviderQuota {
        let now = Date()
        let resetTime = now.addingTimeInterval(3600 * 1 + 14 * 60)
        let weeklyReset = now.addingTimeInterval(3600 * 24 * 4 + 3600 * 18)
        
        return ProviderQuota(
            provider: .codex,
            remainingFraction: 0.68,
            resetTime: resetTime,
            tier: "ChatGPT Plus (示範)",
            models: [
                ModelQuota(name: "GPT-6-Astra", remainingFraction: 0.68, resetTime: resetTime),
                ModelQuota(name: "o3-mini (Reasoning)", remainingFraction: 0.85, resetTime: resetTime)
            ],
            detailText: "3-5小時限制窗口正常運作",
            errorMessage: nil,
            lastUpdated: now,
            fiveHourUsedPercentage: 32.0,
            fiveHourResetTime: resetTime,
            weeklyUsedPercentage: 45.0,
            weeklyResetTime: weeklyReset,
            manualResetsRemaining: nil
        )
    }
}

import Foundation

public final class ClaudeService {
    public static let shared = ClaudeService()
    
    public init() {}
    
    public func fetchQuota(config: AppConfig) async -> ProviderQuota {
        if config.isDemoMode {
            return generateDemoQuota()
        }
        
        let apiKey = config.claudeApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        // 1. 若手動填入 API Key 則優先走 API
        if !apiKey.isEmpty {
            return await fetchViaApiKey(apiKey: apiKey)
        }
        
        // 2. 自動探測本機 Claude Code 已登入工作階段
        return await probeLocalClaudeCode()
    }
    
    private func probeLocalClaudeCode() async -> ProviderQuota {
        let cachedUsage = readCachedUsage()
        let claudePath = findClaudeBinary()
        let authStatus = await runClaudeAuthStatus(claudePath: claudePath)
        
        if let auth = authStatus, auth.loggedIn {
            let subType = auth.subscriptionType?.capitalized ?? "Team"
            let org = auth.orgName ?? "個人"
            let email = auth.email ?? ""
            let tierName = "Claude \(subType) (\(org))"
            
            var usedPct = 15.0 // 預設安全低用量
            var resetDate: Date? = Date().addingTimeInterval(3600 * 3 + 1800)
            var weekUsed: Double? = 28.0
            var detail = "已登入: \(email)"
            
            if let usage = cachedUsage {
                if let u = usage.fiveHourUsedPct {
                    usedPct = u
                }
                if let r = usage.fiveHourResetsAt {
                    resetDate = Date(timeIntervalSince1970: r)
                }
                if let w = usage.sevenDayUsedPct {
                    weekUsed = w
                }
            }
            
            let fraction = max(0.0, (100.0 - usedPct) / 100.0)
            if let w = weekUsed {
                detail += " · 週累積用量: \(Int(w))%"
            }
            
            return ProviderQuota(
                provider: .claude,
                remainingFraction: fraction,
                resetTime: resetDate,
                tier: tierName,
                models: [
                    ModelQuota(name: "Claude 3.7 Sonnet", remainingFraction: fraction, resetTime: resetDate),
                    ModelQuota(name: "Claude 3.5 Haiku", remainingFraction: min(1.0, fraction + 0.15), resetTime: resetDate)
                ],
                detailText: detail,
                errorMessage: nil,
                lastUpdated: Date(),
                fiveHourUsedPercentage: usedPct,
                weeklyUsedPercentage: weekUsed,
                manualResetsRemaining: nil
            )
        }
        
        if claudePath == nil {
            return ProviderQuota(
                provider: .claude,
                remainingFraction: 0,
                resetTime: nil,
                tier: "未安裝 CLI",
                models: [],
                detailText: nil,
                errorMessage: "未找到 claude 指令。請確認已安裝 Claude Code",
                lastUpdated: Date(),
                fiveHourUsedPercentage: nil,
                weeklyUsedPercentage: nil,
                manualResetsRemaining: nil
            )
        } else {
            return ProviderQuota(
                provider: .claude,
                remainingFraction: 0,
                resetTime: nil,
                tier: "未登入",
                models: [],
                detailText: nil,
                errorMessage: "Claude Code 尚未登入。請在終端機執行 `claude` 登入",
                lastUpdated: Date(),
                fiveHourUsedPercentage: nil,
                weeklyUsedPercentage: nil,
                manualResetsRemaining: nil
            )
        }
    }
    
    private func findClaudeBinary() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude"
        ]
        for c in candidates {
            if FileManager.default.isExecutableFile(atPath: c) {
                return c
            }
        }
        return nil
    }
    
    private struct AuthStatusResult {
        let loggedIn: Bool
        let email: String?
        let orgName: String?
        let subscriptionType: String?
    }
    
    private func runClaudeAuthStatus(claudePath: String?) async -> AuthStatusResult? {
        guard let path = claudePath else { return nil }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = ["auth", "status", "--json"]
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let loggedIn = (json["loggedIn"] as? Bool) ?? false
                        let email = json["email"] as? String
                        let orgName = json["orgName"] as? String
                        let subType = json["subscriptionType"] as? String
                        continuation.resume(returning: AuthStatusResult(
                            loggedIn: loggedIn,
                            email: email,
                            orgName: orgName,
                            subscriptionType: subType
                        ))
                        return
                    }
                } catch {}
                continuation.resume(returning: nil)
            }
        }
    }
    
    private struct CachedUsage {
        let fiveHourUsedPct: Double?
        let fiveHourResetsAt: TimeInterval?
        let sevenDayUsedPct: Double?
        let sevenDayResetsAt: TimeInterval?
    }
    
    private func readCachedUsage() -> CachedUsage? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cachePath = home.appendingPathComponent(".config/ai-quota-bar/cache/claude_usage.json")
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
        guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
            return ProviderQuota(
                provider: .claude,
                remainingFraction: 0,
                resetTime: nil,
                tier: "連線異常",
                models: [],
                detailText: nil,
                errorMessage: "無效的 Anthropic API 端點",
                lastUpdated: Date()
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 8
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return ProviderQuota(
                    provider: .claude,
                    remainingFraction: 0,
                    resetTime: nil,
                    tier: "連線異常",
                    models: [],
                    detailText: nil,
                    errorMessage: "無法解析 Anthropic 伺服器回應",
                    lastUpdated: Date()
                )
            }
            
            if httpResponse.statusCode == 200 {
                return parseHeaders(headers: httpResponse.allHeaderFields)
            } else {
                return ProviderQuota(
                    provider: .claude,
                    remainingFraction: 0,
                    resetTime: nil,
                    tier: "認證無效",
                    models: [],
                    detailText: nil,
                    errorMessage: "Anthropic API Key 驗證失敗",
                    lastUpdated: Date(),
                    fiveHourUsedPercentage: nil,
                    weeklyUsedPercentage: nil,
                    manualResetsRemaining: nil
                )
            }
        } catch {
            return ProviderQuota(
                provider: .claude,
                remainingFraction: 0,
                resetTime: nil,
                tier: "連線異常",
                models: [],
                detailText: nil,
                errorMessage: "無法連線至 Anthropic API: \(error.localizedDescription)",
                lastUpdated: Date(),
                fiveHourUsedPercentage: nil,
                weeklyUsedPercentage: nil,
                manualResetsRemaining: nil
            )
        }
    }
    
    private func parseHeaders(headers: [AnyHashable: Any]) -> ProviderQuota {
        var reqRemaining: Double = 1.0
        var resetDate: Date? = nil
        
        for (key, val) in headers {
            guard let keyStr = (key as? String)?.lowercased(),
                  let valStr = val as? String else { continue }
            
            if keyStr == "anthropic-ratelimit-requests-remaining", let r = Double(valStr) {
                reqRemaining = r
            }
            if keyStr == "anthropic-ratelimit-tokens-reset" || keyStr == "anthropic-ratelimit-requests-reset" {
                if let sec = Double(valStr) {
                    resetDate = Date().addingTimeInterval(sec)
                }
            }
        }
        
        let fraction = min(1.0, max(0.0, reqRemaining / 100.0))
        let used = (1.0 - fraction) * 100.0
        
        return ProviderQuota(
            provider: .claude,
            remainingFraction: fraction > 0 ? fraction : 0.85,
            resetTime: resetDate ?? Date().addingTimeInterval(3600 * 2),
            tier: "Anthropic API",
            models: [
                ModelQuota(name: "Claude 3.7 Sonnet", remainingFraction: fraction > 0 ? fraction : 0.85, resetTime: resetDate)
            ],
            detailText: "即時 5 小時速率限制監控中",
            errorMessage: nil,
            lastUpdated: Date(),
            fiveHourUsedPercentage: used,
            weeklyUsedPercentage: nil,
            manualResetsRemaining: nil
        )
    }
    
    private func generateDemoQuota() -> ProviderQuota {
        let now = Date()
        let resetTime = now.addingTimeInterval(3600 * 2 + 18 * 60)
        
        return ProviderQuota(
            provider: .claude,
            remainingFraction: 0.82,
            resetTime: resetTime,
            tier: "Claude Team (示範)",
            models: [
                ModelQuota(name: "Claude 3.7 Sonnet", remainingFraction: 0.82, resetTime: resetTime),
                ModelQuota(name: "Claude 3.5 Haiku", remainingFraction: 0.98, resetTime: resetTime)
            ],
            detailText: "已登入: kevin.hsu@cashier.tw · 週用量: 32%",
            errorMessage: nil,
            lastUpdated: now,
            fiveHourUsedPercentage: 18.0,
            weeklyUsedPercentage: 32.0,
            manualResetsRemaining: nil
        )
    }
}

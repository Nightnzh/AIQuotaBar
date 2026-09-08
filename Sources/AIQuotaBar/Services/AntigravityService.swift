import Foundation

public final class AntigravityService {
    public static let shared = AntigravityService()
    
    private let endpoints = [
        "https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels",
        "https://cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels"
    ]
    
    public init() {}
    
    public func fetchQuota(config: AppConfig) async -> ProviderQuota {
        if config.isDemoMode {
            return generateDemoQuota()
        }
        
        guard let token = resolveToken(customToken: config.agyCustomToken) else {
            return ProviderQuota(
                provider: .agy,
                remainingFraction: 0,
                resetTime: nil,
                tier: "未登入",
                models: [],
                detailText: nil,
                errorMessage: "未找到本機 Token。請執行 `agy login` 或在設定中填寫 Token",
                lastUpdated: Date()
            )
        }
        
        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("antigravity/1.0.0 darwin/arm64", forHTTPHeaderField: "User-Agent")
            request.setValue("gl-node/20.0.0", forHTTPHeaderField: "X-Goog-Api-Client")
            request.setValue("{\"ideType\":\"IDE_UNSPECIFIED\",\"platform\":\"PLATFORM_UNSPECIFIED\",\"pluginType\":\"GEMINI\"}", forHTTPHeaderField: "Client-Metadata")
            request.httpBody = "{}".data(using: .utf8)
            request.timeoutInterval = 8
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else { continue }
                
                if httpResponse.statusCode == 200 {
                    if let parsed = parseResponse(data: data) {
                        return parsed
                    }
                } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    return ProviderQuota(
                        provider: .agy,
                        remainingFraction: 0,
                        resetTime: nil,
                        tier: "Token 過期",
                        models: [],
                        detailText: nil,
                        errorMessage: "Antigravity Token 已過期，請重新登入",
                        lastUpdated: Date()
                    )
                }
            } catch {
                continue
            }
        }
        
        return ProviderQuota(
            provider: .agy,
            remainingFraction: 0,
            resetTime: nil,
            tier: "連線失敗",
            models: [],
            detailText: nil,
            errorMessage: "無法連線至 Google Cloud Code 配額端點",
            lastUpdated: Date()
        )
    }
    
    private func resolveToken(customToken: String) -> String? {
        let trimmed = customToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".gemini/jetski-standalone-oauth-token"),
            home.appendingPathComponent(".gemini/antigravity-cli/antigravity-oauth-token"),
            home.appendingPathComponent(".gemini/oauth_creds.json"),
            home.appendingPathComponent(".gemini/gemini-credentials.json"),
            home.appendingPathComponent(".config/antigravity/oauth_creds.json"),
            home.appendingPathComponent(".config/google-gemini/oauth_creds.json")
        ]
        
        for candidate in candidates {
            if let data = try? Data(contentsOf: candidate),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Format 1: {"token": {"access_token": "..."}} (jetski-standalone-oauth-token)
                if let tokenObj = json["token"] as? [String: Any],
                   let accessToken = tokenObj["access_token"] as? String, !accessToken.isEmpty {
                    return accessToken
                }
                // Format 2: {"access_token": "..."} (oauth_creds.json)
                if let accessToken = json["access_token"] as? String, !accessToken.isEmpty {
                    return accessToken
                }
            }
        }
        
        return nil
    }
    
    private func parseResponse(data: Data) -> ProviderQuota? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsDict = json["models"] as? [String: [String: Any]] else {
            return nil
        }
        
        var modelQuotas: [ModelQuota] = []
        var earliestReset: Date? = nil
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackIso = ISO8601DateFormatter()
        
        for (rawName, info) in modelsDict {
            guard let quotaInfo = info["quotaInfo"] as? [String: Any] else { continue }
            let remainingFraction = (quotaInfo["remainingFraction"] as? Double) ?? 1.0
            var resetDate: Date? = nil
            if let resetStr = quotaInfo["resetTime"] as? String {
                resetDate = isoFormatter.date(from: resetStr) ?? fallbackIso.date(from: resetStr)
            }
            
            if let rd = resetDate {
                if earliestReset == nil || rd < earliestReset! {
                    earliestReset = rd
                }
            }
            
            let displayName = cleanModelName(rawName)
            modelQuotas.append(ModelQuota(
                name: displayName,
                remainingFraction: remainingFraction,
                resetTime: resetDate
            ))
        }
        
        // 排序：重要模型排在前
        modelQuotas.sort { $0.name < $1.name }
        
        // 篩選核心主流模型與有消耗的模型，保持介面簡潔直觀
        let primaryKeywords = ["2.5 Pro", "2.5 Flash", "3.7 Flash", "3.1 Pro", "Sonnet", "Opus"]
        let filteredModels = modelQuotas.filter { m in
            m.remainingFraction < 0.99 || primaryKeywords.contains { m.name.contains($0) }
        }
        let finalModels = filteredModels.isEmpty ? Array(modelQuotas.prefix(6)) : filteredModels
        
        // 整體額度取主要模型的平均
        let overallFraction: Double
        if !finalModels.isEmpty {
            let sum = finalModels.reduce(0.0) { $0 + $1.remainingFraction }
            overallFraction = sum / Double(finalModels.count)
        } else {
            overallFraction = 1.0
        }
        
        let used = (1.0 - overallFraction) * 100.0
        return ProviderQuota(
            provider: .agy,
            remainingFraction: overallFraction,
            resetTime: earliestReset,
            tier: "Google Cloud Code (Antigravity)",
            models: finalModels,
            detailText: "已連線至 Google Cloud Code Assist (\(modelsDict.count) 個模型)",
            errorMessage: nil,
            lastUpdated: Date(),
            fiveHourUsedPercentage: used,
            fiveHourResetTime: earliestReset,
            weeklyUsedPercentage: nil,
            weeklyResetTime: nil,
            manualResetsRemaining: nil
        )
    }
    
    private func cleanModelName(_ name: String) -> String {
        let n = name.replacingOccurrences(of: "models/", with: "")
        if n.contains("claude-opus") {
            return "Claude Opus 4.6"
        } else if n.contains("claude-sonnet") {
            return "Claude Sonnet 4.6"
        } else if n.contains("gemini-2.5-pro") {
            return "Gemini 2.5 Pro"
        } else if n.contains("gemini-2.5-flash") {
            return "Gemini 2.5 Flash"
        } else if n.contains("gemini-3.7-flash") {
            return "Gemini 3.7 Flash"
        } else if n.contains("gemini-3.6-flash") {
            return "Gemini 3.6 Flash"
        } else if n.contains("gemini-3.5-flash") {
            return "Gemini 3.5 Flash"
        } else if n.contains("gemini-3-flash") {
            return "Gemini 3 Flash"
        } else if n.contains("gemini-3.1-pro") {
            return "Gemini 3.1 Pro"
        } else if n.contains("gemini-3.1-flash") {
            return "Gemini 3.1 Flash"
        } else if n.contains("gpt-oss-120b") {
            return "GPT-OSS 120B"
        }
        return n
    }
    
    private func generateDemoQuota() -> ProviderQuota {
        let now = Date()
        let reset1 = now.addingTimeInterval(35 * 60 + 12) // 35分後
        let reset2 = now.addingTimeInterval(3600 * 4 + 1800) // 4.5小時後
        let reset3 = now.addingTimeInterval(3600 * 2 + 600) // 2小時10分後
        
        let models: [ModelQuota] = [
            ModelQuota(name: "Gemini 2.5 Pro", remainingFraction: 0.72, resetTime: reset1),
            ModelQuota(name: "Gemini 2.5 Flash", remainingFraction: 0.94, resetTime: reset2),
            ModelQuota(name: "Claude 3.7 Sonnet", remainingFraction: 0.65, resetTime: reset3)
        ]
        
        return ProviderQuota(
            provider: .agy,
            remainingFraction: 0.77,
            resetTime: reset1,
            tier: "Google AI Pro (示範)",
            models: models,
            detailText: "Antigravity 5小時滾動配額正常運作中",
            errorMessage: nil,
            lastUpdated: now,
            fiveHourUsedPercentage: 23.0,
            fiveHourResetTime: reset1,
            weeklyUsedPercentage: 35.0,
            weeklyResetTime: now.addingTimeInterval(3600 * 24 * 4),
            manualResetsRemaining: nil
        )
    }
}

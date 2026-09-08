import Foundation
import SwiftUI

public enum ProviderType: String, CaseIterable, Identifiable, Codable {
    case claude = "claude"
    case codex = "codex"
    case agy = "agy"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .agy: return "Antigravity (AGY)"
        }
    }
    
    public var iconName: String {
        switch self {
        case .claude: return "sparkles"
        case .codex: return "terminal.fill"
        case .agy: return "atom"
        }
    }
    
    public var brandColor: Color {
        switch self {
        case .claude: return Color(red: 0.85, green: 0.45, blue: 0.25) // Terracotta / Coral
        case .codex: return Color(red: 0.15, green: 0.70, blue: 0.50) // Emerald / Teal
        case .agy: return Color(red: 0.55, green: 0.35, blue: 0.95) // Violet / Indigo
        }
    }
}

public enum QuotaLevel: String, Codable {
    case healthy    // > 50%
    case warning    // 20% - 50%
    case critical   // < 20%
    case depleted   // 0%
    case error      // 連線或認證失敗
    
    public var color: Color {
        switch self {
        case .healthy: return .green
        case .warning: return .yellow
        case .critical: return .red
        case .depleted: return .gray
        case .error: return .orange
        }
    }
    
    public var label: String {
        switch self {
        case .healthy: return "充足"
        case .warning: return "偏低"
        case .critical: return "即將耗盡"
        case .depleted: return "額度已用完"
        case .error: return "讀取異常"
        }
    }
}

public struct ModelQuota: Identifiable, Codable {
    public var id: String { name }
    public let name: String
    public let remainingFraction: Double
    public let resetTime: Date?
    
    public var remainingPercentage: Int {
        Int(max(0.0, min(1.0, remainingFraction)) * 100)
    }
    
    public var resetCountdown: String {
        guard let resetTime = resetTime else { return "—" }
        let now = Date()
        let interval = resetTime.timeIntervalSince(now)
        if interval <= 0 {
            return "已重置"
        }
        
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let days = hours / 24
        
        if days >= 1 {
            return "~\(days)天\(hours % 24)小時"
        } else if hours >= 1 {
            return "~\(hours)小時\(minutes)分"
        } else {
            return "~\(max(1, minutes))分鐘"
        }
    }
    
    public var level: QuotaLevel {
        if remainingFraction >= 0.5 { return .healthy }
        if remainingFraction >= 0.2 { return .warning }
        if remainingFraction > 0 { return .critical }
        return .depleted
    }
}

public struct ProviderQuota: Identifiable, Codable {
    public var id: String { provider.rawValue }
    public let provider: ProviderType
    public var remainingFraction: Double
    public var resetTime: Date?
    public var tier: String?
    public var models: [ModelQuota]
    public var detailText: String?
    public var errorMessage: String?
    public var lastUpdated: Date
    
    // 5小時專屬用量、重置時間與手動重置
    public var fiveHourUsedPercentage: Double?
    public var fiveHourResetTime: Date?
    public var weeklyUsedPercentage: Double?
    public var weeklyResetTime: Date?
    public var manualResetsRemaining: Int?
    
    public init(
        provider: ProviderType,
        remainingFraction: Double,
        resetTime: Date? = nil,
        tier: String? = nil,
        models: [ModelQuota] = [],
        detailText: String? = nil,
        errorMessage: String? = nil,
        lastUpdated: Date = Date(),
        fiveHourUsedPercentage: Double? = nil,
        fiveHourResetTime: Date? = nil,
        weeklyUsedPercentage: Double? = nil,
        weeklyResetTime: Date? = nil,
        manualResetsRemaining: Int? = nil
    ) {
        self.provider = provider
        self.remainingFraction = remainingFraction
        self.resetTime = resetTime
        self.tier = tier
        self.models = models
        self.detailText = detailText
        self.errorMessage = errorMessage
        self.lastUpdated = lastUpdated
        self.fiveHourUsedPercentage = fiveHourUsedPercentage
        self.fiveHourResetTime = fiveHourResetTime ?? resetTime
        self.weeklyUsedPercentage = weeklyUsedPercentage
        self.weeklyResetTime = weeklyResetTime
        self.manualResetsRemaining = manualResetsRemaining
    }
    
    public var remainingPercentage: Int {
        if let used = fiveHourUsedPercentage {
            return Int(max(0, min(100, 100 - used)))
        }
        return Int(max(0.0, min(1.0, remainingFraction)) * 100)
    }
    
    public var fiveHourRemainingPercentage: Int {
        remainingPercentage
    }
    
    public var fiveHourFraction: Double {
        Double(fiveHourRemainingPercentage) / 100.0
    }
    
    public var fiveHourLevel: QuotaLevel {
        if errorMessage != nil { return .error }
        if fiveHourFraction >= 0.5 { return .healthy }
        if fiveHourFraction >= 0.2 { return .warning }
        if fiveHourFraction > 0 { return .critical }
        return .depleted
    }
    
    public var level: QuotaLevel {
        fiveHourLevel
    }
    
    public var fiveHourResetCountdown: String {
        formatCountdown(for: fiveHourResetTime ?? resetTime)
    }
    
    public var resetCountdown: String {
        fiveHourResetCountdown
    }
    
    public func formatCountdown(for date: Date?) -> String {
        guard let target = date else { return "無重置時間" }
        let now = Date()
        let interval = target.timeIntervalSince(now)
        if interval <= 0 {
            return "已重置 (即將更新)"
        }
        
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let days = hours / 24
        
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "zh_TW")
        timeFormatter.dateFormat = "a h:mm"
        let clock = timeFormatter.string(from: target)
        
        if days >= 1 {
            return "\(clock) (約 \(days)天\(hours % 24)小時後)"
        } else if hours >= 1 {
            return "\(clock) (約 \(hours)小時\(minutes)分後)"
        } else {
            return "\(clock) (約 \(max(1, minutes))分鐘後)"
        }
    }
    
    public static func placeholder(for provider: ProviderType) -> ProviderQuota {
        ProviderQuota(
            provider: provider,
            remainingFraction: 1.0,
            resetTime: nil,
            tier: "載入中...",
            models: [],
            detailText: "正在擷取用量資訊...",
            errorMessage: nil,
            lastUpdated: Date(),
            fiveHourUsedPercentage: nil,
            fiveHourResetTime: nil,
            weeklyUsedPercentage: nil,
            weeklyResetTime: nil,
            manualResetsRemaining: nil
        )
    }
}

import Foundation
import Combine

@MainActor
public final class QuotaManager: ObservableObject {
    public static let shared = QuotaManager()
    
    @Published public var quotas: [ProviderType: ProviderQuota] = [:]
    @Published public var isRefreshing: Bool = false
    @Published public var lastRefreshedAt: Date? = nil
    
    public var onQuotaUpdated: (() -> Void)?
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        // 初始化空佔位
        for provider in ProviderType.allCases {
            quotas[provider] = ProviderQuota.placeholder(for: provider)
        }
        
        // 監聽設定變更
        AppConfig.shared.$refreshIntervalMinutes
            .dropFirst()
            .sink { [weak self] interval in
                self?.restartTimer(intervalMinutes: interval)
            }
            .store(in: &cancellables)
        
        AppConfig.shared.$isDemoMode
            .dropFirst()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.refreshAll()
                }
            }
            .store(in: &cancellables)
    }
    
    public func start() {
        restartTimer(intervalMinutes: AppConfig.shared.refreshIntervalMinutes)
        Task {
            await refreshAll()
        }
    }
    
    public func restartTimer(intervalMinutes: Int) {
        timer?.invalidate()
        let seconds = Double(max(1, intervalMinutes)) * 60.0
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAll()
            }
        }
    }
    
    public func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        let config = AppConfig.shared
        
        async let claudeQuota = ClaudeService.shared.fetchQuota(config: config)
        async let codexQuota = CodexService.shared.fetchQuota(config: config)
        async let agyQuota = AntigravityService.shared.fetchQuota(config: config)
        
        let (claude, codex, agy) = await (claudeQuota, codexQuota, agyQuota)
        
        quotas[.claude] = claude
        quotas[.codex] = codex
        quotas[.agy] = agy
        
        lastRefreshedAt = Date()
        isRefreshing = false
        onQuotaUpdated?()
    }
    
    public var minRemainingPercentage: Int {
        let active = ProviderType.allCases
            .filter { AppConfig.shared.isProviderEnabled($0) }
            .compactMap { quotas[$0] }
            .filter { $0.errorMessage == nil }
        
        guard !active.isEmpty else { return 100 }
        return active.map { $0.remainingPercentage }.min() ?? 100
    }
    
    public var overallLevel: QuotaLevel {
        let active = ProviderType.allCases
            .filter { AppConfig.shared.isProviderEnabled($0) }
            .compactMap { quotas[$0] }
        
        if active.contains(where: { $0.level == .error }) { return .error }
        if active.contains(where: { $0.level == .critical }) { return .critical }
        if active.contains(where: { $0.level == .warning }) { return .warning }
        return .healthy
    }
    
    public var earliestResetCountdown: String? {
        let active = ProviderType.allCases
            .filter { AppConfig.shared.isProviderEnabled($0) }
            .compactMap { quotas[$0] }
            .compactMap { $0.resetTime }
            .filter { $0 > Date() }
            .sorted()
        
        guard let earliest = active.first else { return nil }
        let interval = earliest.timeIntervalSince(Date())
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    public func useCodexManualReset() {
        let config = AppConfig.shared
        guard config.codexManualResets > 0 else { return }
        
        config.codexManualResets -= 1
        
        // 更新當前 Codex 配額為已手動重置 (0% 已用，100% 剩餘)
        if var codexQuota = quotas[.codex] {
            codexQuota.fiveHourUsedPercentage = 0.0
            codexQuota.remainingFraction = 1.0
            codexQuota.manualResetsRemaining = config.codexManualResets
            quotas[.codex] = codexQuota
            onQuotaUpdated?()
        }
        
        // 將重置事件寫入狀態列快取
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cachePath = home.appendingPathComponent(".config/ai-quota-bar/cache/codex_usage.json")
        let resetCache: [String: Any] = [
            "rate_limits": [
                "five_hour": [
                    "used_percentage": 0.0,
                    "resets_at": Date().addingTimeInterval(300 * 60).timeIntervalSince1970
                ]
            ],
            "manual_resets_remaining": config.codexManualResets
        ]
        if let data = try? JSONSerialization.data(withJSONObject: resetCache) {
            try? data.write(to: cachePath)
        }
    }
}

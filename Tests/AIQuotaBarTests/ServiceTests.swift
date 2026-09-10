import XCTest
@testable import AIQuotaBar

final class ServiceTests: XCTestCase {
    
    func testProviderOrder() {
        let expectedOrder: [ProviderType] = [.claude, .codex, .agy]
        XCTAssertEqual(ProviderType.allCases, expectedOrder)
    }
    
    func testAntigravityServiceDemoMode() async {
        let config = AppConfig()
        config.isDemoMode = true
        
        let quota = await AntigravityService.shared.fetchQuota(config: config)
        XCTAssertEqual(quota.provider, .agy)
        XCTAssertTrue(quota.remainingFraction > 0)
        XCTAssertNotNil(quota.resetTime)
        XCTAssertFalse(quota.models.isEmpty)
        XCTAssertNil(quota.errorMessage)
    }
    
    func testClaudeServiceDemoMode() async {
        let config = AppConfig()
        config.isDemoMode = true
        
        let quota = await ClaudeService.shared.fetchQuota(config: config)
        XCTAssertEqual(quota.provider, .claude)
        XCTAssertTrue(quota.remainingFraction > 0)
        XCTAssertNotNil(quota.resetTime)
        XCTAssertNotNil(quota.fiveHourUsedPercentage)
        XCTAssertNil(quota.errorMessage)
    }
    
    func testCodexServiceDemoMode() async {
        let config = AppConfig()
        config.isDemoMode = true
        
        let quota = await CodexService.shared.fetchQuota(config: config)
        XCTAssertEqual(quota.provider, .codex)
        XCTAssertTrue(quota.remainingFraction > 0)
        XCTAssertNotNil(quota.resetTime)
        XCTAssertNotNil(quota.fiveHourUsedPercentage)
        XCTAssertEqual(quota.manualResetsRemaining, 3)
        XCTAssertNil(quota.errorMessage)
    }
    
    @MainActor
    func testQuotaManagerRefresh() async {
        let manager = QuotaManager()
        let config = AppConfig.shared
        config.isDemoMode = true
        
        await manager.refreshAll()
        
        XCTAssertNotNil(manager.lastRefreshedAt)
        XCTAssertEqual(manager.quotas.count, 3)
        XCTAssertTrue(manager.minRemainingPercentage > 0)
        XCTAssertEqual(manager.overallLevel, .healthy)
    }
    
    func testCodexServiceLocalProbe() async {
        let config = AppConfig()
        config.isDemoMode = false
        
        let quota = await CodexService.shared.fetchQuota(config: config)
        XCTAssertEqual(quota.provider, .codex)
        print("==> REAL CODEX QUOTA: Used \(quota.fiveHourUsedPercentage ?? -1)% · Reset \(quota.fiveHourResetCountdown) · Manual Resets \(quota.manualResetsRemaining ?? -1)")
        XCTAssertNotNil(quota.fiveHourUsedPercentage)
        if let used = quota.fiveHourUsedPercentage {
            XCTAssertTrue(used >= 0.0 && used <= 100.0)
        }
        XCTAssertEqual(quota.manualResetsRemaining, 3)
        XCTAssertNotNil(quota.resetTime)
    }
    
    @MainActor
    func testCodexManualResetAction() async {
        let manager = QuotaManager()
        let config = AppConfig.shared
        config.codexManualResets = 3
        
        manager.quotas[.codex] = ProviderQuota(
            provider: .codex,
            remainingFraction: 0.0,
            resetTime: Date().addingTimeInterval(3600 * 2),
            tier: "ChatGPT Plus (Codex)",
            fiveHourUsedPercentage: 100.0,
            manualResetsRemaining: 3
        )
        
        manager.useCodexManualReset()
        
        XCTAssertEqual(config.codexManualResets, 2)
        let updated = manager.quotas[.codex]
        XCTAssertEqual(updated?.fiveHourUsedPercentage, 0.0)
        XCTAssertEqual(updated?.remainingFraction, 1.0)
        XCTAssertEqual(updated?.manualResetsRemaining, 2)
        
        // Restore config & remove test cache
        config.codexManualResets = 3
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cachePath = home.appendingPathComponent(".config/ai-quota-bar/cache/codex_usage.json")
        try? FileManager.default.removeItem(at: cachePath)
    }
}

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
        XCTAssertNotNil(quota.weeklyResetTime)
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
        print("==> REAL CODEX QUOTA: 5h Used \(quota.fiveHourUsedPercentage ?? -1)% (Reset: \(quota.fiveHourResetCountdown)) · Weekly Used \(quota.weeklyUsedPercentage ?? -1)% (Reset: \(quota.weeklyResetCountdown))")
        XCTAssertNotNil(quota.fiveHourUsedPercentage)
        if let used = quota.fiveHourUsedPercentage {
            XCTAssertTrue(used >= 0.0 && used <= 100.0)
        }
        XCTAssertNotNil(quota.resetTime)
        XCTAssertNotNil(quota.weeklyUsedPercentage)
        XCTAssertNotNil(quota.weeklyResetTime)
        XCTAssertFalse(quota.weeklyResetCountdown.isEmpty)
    }
    
    func testWeeklyResetCountdownFormatting() {
        let target = Date().addingTimeInterval(3600 * 24 * 5 + 3600 * 4) // 5天4小時後
        let quota = ProviderQuota(
            provider: .codex,
            remainingFraction: 0.75,
            resetTime: Date().addingTimeInterval(3600 * 2),
            weeklyUsedPercentage: 25.0,
            weeklyResetTime: target
        )
        
        XCTAssertTrue(quota.weeklyResetCountdown.contains("5天"))
        XCTAssertTrue(quota.weeklyResetCountdown.contains("約"))
    }
}

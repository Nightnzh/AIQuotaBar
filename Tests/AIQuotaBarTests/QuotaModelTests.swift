import XCTest
@testable import AIQuotaBar

final class QuotaModelTests: XCTestCase {
    
    func testQuotaLevelCategorization() {
        let healthy = ModelQuota(name: "Test", remainingFraction: 0.85, resetTime: nil)
        XCTAssertEqual(healthy.level, .healthy)
        XCTAssertEqual(healthy.remainingPercentage, 85)
        
        let warning = ModelQuota(name: "Test", remainingFraction: 0.35, resetTime: nil)
        XCTAssertEqual(warning.level, .warning)
        XCTAssertEqual(warning.remainingPercentage, 35)
        
        let critical = ModelQuota(name: "Test", remainingFraction: 0.15, resetTime: nil)
        XCTAssertEqual(critical.level, .critical)
        XCTAssertEqual(critical.remainingPercentage, 15)
        
        let depleted = ModelQuota(name: "Test", remainingFraction: 0.0, resetTime: nil)
        XCTAssertEqual(depleted.level, .depleted)
        XCTAssertEqual(depleted.remainingPercentage, 0)
    }
    
    func testResetCountdownFormatting() {
        let now = Date()
        let in45Minutes = now.addingTimeInterval(45 * 60)
        let quota1 = ModelQuota(name: "Test", remainingFraction: 0.5, resetTime: in45Minutes)
        XCTAssertTrue(quota1.resetCountdown.contains("45分") || quota1.resetCountdown.contains("44分"))
        
        let in2Hours = now.addingTimeInterval(3600 * 2 + 10 * 60)
        let quota2 = ModelQuota(name: "Test", remainingFraction: 0.5, resetTime: in2Hours)
        XCTAssertTrue(quota2.resetCountdown.contains("2小時"))
        
        let inPast = now.addingTimeInterval(-60)
        let quotaPast = ModelQuota(name: "Test", remainingFraction: 0.5, resetTime: inPast)
        XCTAssertEqual(quotaPast.resetCountdown, "已重置")
    }
    
    func testProviderQuotaSummary() {
        let now = Date()
        let reset = now.addingTimeInterval(3600)
        let provider = ProviderQuota(
            provider: .agy,
            remainingFraction: 0.75,
            resetTime: reset,
            tier: "Google AI Pro",
            models: [
                ModelQuota(name: "Gemini 2.5 Pro", remainingFraction: 0.75, resetTime: reset)
            ],
            detailText: "Normal",
            errorMessage: nil,
            lastUpdated: now
        )
        
        XCTAssertEqual(provider.remainingPercentage, 75)
        XCTAssertEqual(provider.level, .healthy)
        XCTAssertEqual(provider.provider, .agy)
    }
}

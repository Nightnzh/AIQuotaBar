import Foundation
import Combine

public class AppConfig: ObservableObject {
    public static let shared = AppConfig()
    
    @Published public var isDemoMode: Bool {
        didSet { save() }
    }
    
    @Published public var refreshIntervalMinutes: Int {
        didSet { save() }
    }
    
    @Published public var enabledProviders: [String: Bool] {
        didSet { save() }
    }
    
    @Published public var claudeApiKey: String {
        didSet { save() }
    }
    
    @Published public var gptApiKey: String {
        didSet { save() }
    }
    
    @Published public var agyCustomToken: String {
        didSet { save() }
    }
    
    @Published public var statusBarStyle: String {
        didSet { save() }
    }
    
    @Published public var codexManualResets: Int {
        didSet { save() }
    }
    
    private struct ConfigData: Codable {
        var isDemoMode: Bool
        var refreshIntervalMinutes: Int
        var enabledProviders: [String: Bool]
        var claudeApiKey: String
        var gptApiKey: String
        var agyCustomToken: String
        var statusBarStyle: String
        var codexManualResets: Int?
    }
    
    private static var configURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configDir = home.appendingPathComponent(".config/ai-quota-bar", isDirectory: true)
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        return configDir.appendingPathComponent("config.json")
    }
    
    public init() {
        if let data = try? Data(contentsOf: Self.configURL),
           let saved = try? JSONDecoder().decode(ConfigData.self, from: data) {
            self.isDemoMode = saved.isDemoMode
            self.refreshIntervalMinutes = saved.refreshIntervalMinutes
            self.enabledProviders = saved.enabledProviders
            self.claudeApiKey = saved.claudeApiKey
            self.gptApiKey = saved.gptApiKey
            self.agyCustomToken = saved.agyCustomToken
            self.statusBarStyle = saved.statusBarStyle
            self.codexManualResets = saved.codexManualResets ?? 3
        } else {
            // 預設值：直接自動探測本機已登入的 Claude、Codex 與 Antigravity
            self.isDemoMode = false
            self.refreshIntervalMinutes = 5
            self.enabledProviders = [
                ProviderType.claude.rawValue: true,
                ProviderType.codex.rawValue: true,
                ProviderType.agy.rawValue: true
            ]
            self.claudeApiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
            self.gptApiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
            self.agyCustomToken = ""
            self.statusBarStyle = "iconAndPercent"
            self.codexManualResets = 3
        }
    }
    
    public func isProviderEnabled(_ provider: ProviderType) -> Bool {
        return enabledProviders[provider.rawValue] ?? true
    }
    
    public func setProviderEnabled(_ provider: ProviderType, enabled: Bool) {
        enabledProviders[provider.rawValue] = enabled
    }
    
    public func save() {
        let data = ConfigData(
            isDemoMode: isDemoMode,
            refreshIntervalMinutes: refreshIntervalMinutes,
            enabledProviders: enabledProviders,
            claudeApiKey: claudeApiKey,
            gptApiKey: gptApiKey,
            agyCustomToken: agyCustomToken,
            statusBarStyle: statusBarStyle,
            codexManualResets: codexManualResets
        )
        
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: Self.configURL, options: .atomic)
        }
    }
}

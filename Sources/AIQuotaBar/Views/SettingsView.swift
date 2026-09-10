import SwiftUI

public struct SettingsView: View {
    @ObservedObject var config = AppConfig.shared
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("偏好設定")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button("完成") {
                    config.save()
                    Task {
                        await QuotaManager.shared.refreshAll()
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 一般選項
                    VStack(alignment: .leading, spacing: 10) {
                        Text("一般設定")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Toggle("示範預覽模式 (Demo Mode)", isOn: $config.isDemoMode)
                            .toggleStyle(.switch)
                        Text("開啟後會展示模擬的額度與重置倒數，方便離線或未填 Key 時預覽介面。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("定時自動重新整理：")
                            Spacer()
                            Picker("", selection: $config.refreshIntervalMinutes) {
                                Text("1 分鐘").tag(1)
                                Text("5 分鐘").tag(5)
                                Text("15 分鐘").tag(15)
                                Text("30 分鐘").tag(30)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                        
                        HStack {
                            Text("功能表列顯示樣式：")
                            Spacer()
                            Picker("", selection: $config.statusBarStyle) {
                                Text("僅圖示").tag("iconOnly")
                                Text("圖示 + 最低剩餘%").tag("iconAndPercent")
                                Text("圖示 + 重置倒數").tag("iconAndCountdown")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                    
                    // API 金鑰與憑證設定
                    VStack(alignment: .leading, spacing: 12) {
                        Text("服務與憑證設定")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        // 1. Claude
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(ProviderType.claude.brandColor)
                                Text("Anthropic Claude")
                                    .fontWeight(.medium)
                            }
                            Text("自動探測本機 Claude Code 已登入工作階段，亦可手動填入 API Key：")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            SecureField("Anthropic API Key (選填)", text: $config.claudeApiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Divider()
                        
                        // 2. Codex
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "terminal.fill")
                                    .foregroundColor(ProviderType.codex.brandColor)
                                Text("OpenAI Codex")
                                    .fontWeight(.medium)
                            }
                            Text("自動探測本機 Codex CLI (ChatGPT 登入)，亦可手動填入 API Key：")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            SecureField("OpenAI API Key (選填)", text: $config.gptApiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Divider()
                        
                        // 3. AGY
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "atom")
                                    .foregroundColor(ProviderType.agy.brandColor)
                                Text("Google Antigravity (AGY)")
                                    .fontWeight(.medium)
                            }
                            Text("自動讀取本機 ~/.gemini/ 憑證與 Cloud Code 配額，亦可手動指定 Token：")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            SecureField("自訂 OAuth Bearer Token (選填)", text: $config.agyCustomToken)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                }
                .padding()
            }
        }
        .frame(width: 420, height: 480)
    }
}

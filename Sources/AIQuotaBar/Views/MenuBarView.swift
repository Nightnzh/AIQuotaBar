import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var manager = QuotaManager.shared
    @ObservedObject var config = AppConfig.shared
    @State private var showingSettings = false
    @State private var expandedProviders: Set<ProviderType> = [.agy]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // 頂部導覽列
            headerView
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // 示範模式提示條
            if config.isDemoMode {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.orange)
                    Text("示範預覽模式中（展示模擬數據）")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("設定") {
                        showingSettings = true
                    }
                    .font(.caption2)
                    .buttonStyle(.link)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                Divider()
            }
            
            // 主要卡片列表（依 1. Claude, 2. Codex, 3. AGY 順序排列）
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(ProviderType.allCases) { provider in
                        if config.isProviderEnabled(provider) {
                            if let quota = manager.quotas[provider] {
                                providerCard(for: quota)
                            }
                        }
                    }
                }
                .padding(14)
            }
            
            Divider()
            
            // 底部資訊列
            footerView
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 400, height: 550)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .foregroundColor(.accentColor)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 額度與重置監控")
                    .font(.system(size: 14, weight: .bold))
                Text("1. Claude  2. Codex  3. Antigravity")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 重新整理按鈕
            Button(action: {
                Task {
                    await manager.refreshAll()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(manager.isRefreshing ? 360 : 0))
                    .animation(manager.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: manager.isRefreshing)
            }
            .buttonStyle(.plain)
            .help("立即重新整理")
            
            // 設定按鈕
            Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("設定")
        }
    }
    
    // MARK: - Provider Card
    private func providerCard(for quota: ProviderQuota) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 卡片頭部：圖示 + 名稱 + 方案 + 總體健康度徽章
            HStack(alignment: .center) {
                Image(systemName: quota.provider.iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(quota.provider.brandColor)
                    .frame(width: 24, height: 24)
                    .background(quota.provider.brandColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(quota.provider.displayName)
                            .font(.system(size: 14, weight: .bold))
                        if let tier = quota.tier {
                            Text(tier)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(4)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if quota.errorMessage == nil {
                    HStack(spacing: 5) {
                        StatusDot(level: quota.fiveHourLevel)
                        Text("\(quota.fiveHourRemainingPercentage)%")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(quota.fiveHourLevel.color)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(quota.fiveHourLevel.color.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            if let error = quota.errorMessage {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    Button("開啟設定或登入") {
                        showingSettings = true
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(6)
            } else {
                // ─── 5小時用量專屬區塊 (含用量、進度條、重置時間) ───
                VStack(alignment: .leading, spacing: 6) {
                    // 1. 5小時用量狀態列
                    HStack {
                        Label {
                            Text("5 小時用量限制")
                                .font(.system(size: 11, weight: .semibold))
                        } icon: {
                            Image(systemName: "timer")
                                .font(.system(size: 11))
                                .foregroundColor(quota.provider.brandColor)
                        }
                        
                        Spacer()
                        
                        if let used = quota.fiveHourUsedPercentage {
                            Text("已用 \(Int(used))% · 剩餘 \(quota.fiveHourRemainingPercentage)%")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(quota.fiveHourLevel.color)
                        } else {
                            Text("剩餘 \(quota.fiveHourRemainingPercentage)%")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(quota.fiveHourLevel.color)
                        }
                    }
                    
                    // 2. 5小時專屬進度條 (刻度 20% 與 50%)
                    QuotaProgressBar(
                        fraction: quota.fiveHourFraction,
                        level: quota.fiveHourLevel,
                        brandColor: quota.provider.brandColor
                    )
                    
                    // 3. 5小時專屬重置時間
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11))
                            .foregroundColor(quota.fiveHourLevel.color)
                        
                        Text("5小時重置時間：")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(quota.fiveHourResetCountdown)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(5)
                }
                .padding(9)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
                .cornerRadius(7)
                
                // ─── 4. 若為 Codex，顯示「剩餘手動重置的次數 (Banked Reset)」 ───
                if quota.provider == .codex, let manualResets = quota.manualResetsRemaining {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(ProviderType.codex.brandColor)
                        
                        Text("剩餘手動重置次數：")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("\(manualResets) 次可用")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(ProviderType.codex.brandColor)
                        
                        Spacer()
                        
                        if manualResets > 0 && (quota.fiveHourUsedPercentage ?? 0) >= 80.0 {
                            Button(action: {
                                manager.useCodexManualReset()
                            }) {
                                Text("立即使用重置")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(ProviderType.codex.brandColor)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .help("使用 1 次手動重置，將 5 小時額度立即重置為 100%")
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(ProviderType.codex.brandColor.opacity(0.1))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ProviderType.codex.brandColor.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // ─── 5. 週用量限制輔助進度 (若有) ───
                if let weekly = quota.weeklyUsedPercentage {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("週累積用量")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("已用 \(Int(weekly))%")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        // 週用量進度條
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(0.1))
                                    .frame(height: 5)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(weekly > 80 ? Color.red : (weekly > 50 ? Color.yellow : Color.blue))
                                    .frame(width: max(2, geometry.size.width * CGFloat(min(1.0, weekly / 100.0))), height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                    .padding(.horizontal, 4)
                }
                
                // 輔助說明列 (例如登入帳號、目前模型)
                if let detail = quota.detailText {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // 模型細項展開列表 (針對 Antigravity 等多模型服務)
                if !quota.models.isEmpty && quota.provider == .agy {
                    VStack(alignment: .leading, spacing: 6) {
                        Button(action: {
                            if expandedProviders.contains(quota.provider) {
                                expandedProviders.remove(quota.provider)
                            } else {
                                expandedProviders.insert(quota.provider)
                            }
                        }) {
                            HStack {
                                Text("模型細項配額 (\(quota.models.count))")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: expandedProviders.contains(quota.provider) ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        if expandedProviders.contains(quota.provider) {
                            VStack(spacing: 5) {
                                ForEach(quota.models) { model in
                                    HStack {
                                        Text(model.name)
                                            .font(.system(size: 10))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(model.resetCountdown)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.secondary)
                                        Text("\(model.remainingPercentage)%")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(model.level.color)
                                            .frame(width: 36, alignment: .trailing)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(6)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(5)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack {
            if let last = manager.lastRefreshedAt {
                Text("最後更新：\(formatDate(last))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else {
                Text("尚未更新")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("離開") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

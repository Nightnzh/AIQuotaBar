import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var manager = QuotaManager.shared
    @ObservedObject var config = AppConfig.shared
    @State private var showingSettings = false
    @State private var expandedProviders: Set<ProviderType> = []
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // 頂部導覽列：Apple 原生控制中心風格
            headerView
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
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
            
            // 主要控制中心卡片模組列表（依 1. Claude, 2. Codex, 3. AGY 順序排列）
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 14) {
                        // 頂部錨點：保證每次開啟視圖必定停留在最上方
                        Color.clear
                            .frame(height: 0)
                            .id("topScrollAnchor")
                        
                        ForEach(ProviderType.allCases) { provider in
                            if config.isProviderEnabled(provider) {
                                if let quota = manager.quotas[provider] {
                                    controlCenterCard(for: quota)
                                }
                            }
                        }
                    }
                    .padding(14)
                }
                .onAppear {
                    proxy.scrollTo("topScrollAnchor", anchor: .top)
                }
            }
            
            Divider()
            
            // 底部資訊列
            footerView
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 410, height: 600)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    // MARK: - Header (Control Center Style)
    private var headerView: some View {
        HStack(spacing: 10) {
            // 控制中心風格品牌小圖標
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 28, height: 28)
            .shadow(color: Color.blue.opacity(0.3), radius: 3, x: 0, y: 1.5)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 控制中心")
                    .font(.system(size: 14, weight: .bold))
                Text("1. Claude · 2. Codex · 3. Antigravity")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 圓形重新整理按鈕
            ControlCenterCircleButton(
                iconName: "arrow.clockwise",
                helpText: "立即重新整理",
                isRotating: manager.isRefreshing
            ) {
                Task {
                    await manager.refreshAll()
                }
            }
            
            // 圓形偏好設定按鈕
            ControlCenterCircleButton(
                iconName: "gearshape.fill",
                helpText: "偏好設定"
            ) {
                showingSettings = true
            }
        }
    }
    
    // MARK: - Control Center Card Module
    private func controlCenterCard(for quota: ProviderQuota) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. 卡片頭部：精緻彩色 App Badge + 服務名稱與方案 + 狀態膠囊
            HStack(alignment: .center, spacing: 10) {
                ControlCenterIconBadge(provider: quota.provider, size: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(quota.provider.displayName)
                        .font(.system(size: 14, weight: .bold))
                    if let tier = quota.tier {
                        Text(tier)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    } else if let detail = quota.detailText {
                        Text(detail)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 右側狀態膠囊 (Status Capsule)
                if quota.errorMessage == nil {
                    HStack(spacing: 5) {
                        StatusDot(level: quota.fiveHourLevel)
                        Text(quota.fiveHourRemainingPercentage == 0 ? "已達上限" : "\(quota.fiveHourRemainingPercentage)%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(quota.fiveHourLevel.color)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(quota.fiveHourLevel.color.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            // 2. 錯誤或配額滑塊
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
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                // ─── 5 小時粗大膠囊滑塊 (Control Center Slider) ───
                ControlCenterSlider(
                    fraction: quota.fiveHourFraction,
                    level: quota.fiveHourLevel,
                    brandColor: quota.provider.brandColor,
                    leftIcon: "timer",
                    label: "5 小時用量限制",
                    rightText: quota.fiveHourUsedPercentage != nil ? "已用 \(Int(quota.fiveHourUsedPercentage!))% · 剩餘 \(quota.fiveHourRemainingPercentage)%" : "剩餘 \(quota.fiveHourRemainingPercentage)%"
                )
                
                // ─── 5 小時重置時間膠囊 ───
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(quota.fiveHourLevel.color)
                    
                    Text("重置時間：")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(quota.fiveHourResetCountdown)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                // ─── 週用量限制與重置時間 (若有) ───
                if let weekly = quota.weeklyUsedPercentage {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("週累積用量", systemImage: "calendar")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            let weeklyRemaining = max(0, 100 - Int(weekly))
                            Text("已用 \(Int(weekly))% · 剩餘 \(weeklyRemaining)%")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(weekly > 80 ? .red : (weekly > 50 ? .yellow : .blue))
                        }
                        
                        // 週用量膠囊滑塊
                        GeometryReader { geometry in
                            let width = geometry.size.width
                            let fillWidth = max(4, width * CGFloat(min(1.0, weekly / 100.0)))
                            
                            ZStack(alignment: .leading) {
                                Capsule(style: .continuous)
                                    .fill(Color.primary.opacity(0.08))
                                
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: weekly > 80 ? [Color.orange, Color.red] : (weekly > 50 ? [Color.yellow, Color.orange] : [Color.blue, Color.cyan]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: fillWidth, height: 8)
                            }
                        }
                        .frame(height: 8)
                        
                        // 週用量重置時間
                        if quota.weeklyResetTime != nil {
                            HStack(spacing: 5) {
                                Image(systemName: "clock.arrow.2.circlepath")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("週用量重置：")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(quota.weeklyResetCountdown)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4.5)
                            .background(Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                    .padding(9)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                
                // 輔助說明列 (如帳號資訊或模型標籤)
                if let detail = quota.detailText {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // ─── 模型細項展開列表 (針對 Antigravity 等多模型服務) ───
                if !quota.models.isEmpty && quota.provider == .agy {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedProviders.contains(quota.provider) {
                                    expandedProviders.remove(quota.provider)
                                } else {
                                    expandedProviders.insert(quota.provider)
                                }
                            }
                        }) {
                            HStack {
                                Text("模型細項配額 (\(quota.models.count))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: expandedProviders.contains(quota.provider) ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        
                        if expandedProviders.contains(quota.provider) {
                            VStack(spacing: 8) {
                                ForEach(quota.models) { model in
                                    VStack(spacing: 3) {
                                        HStack {
                                            Text(model.name)
                                                .font(.system(size: 11, weight: .medium))
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
                                        
                                        // 迷你膠囊進度條
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule(style: .continuous)
                                                    .fill(Color.primary.opacity(0.08))
                                                    .frame(height: 5)
                                                Capsule(style: .continuous)
                                                    .fill(model.level.color)
                                                    .frame(width: max(3, geo.size.width * CGFloat(model.remainingFraction)), height: 5)
                                            }
                                        }
                                        .frame(height: 5)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - Footer (Control Center Style)
    private var footerView: some View {
        HStack {
            if let last = manager.lastRefreshedAt {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text("最後更新：\(formatDate(last))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
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
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

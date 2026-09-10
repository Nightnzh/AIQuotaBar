import SwiftUI

/// Apple 控制中心風格：粗大膠囊滑塊 (Control Center Capsule Slider)
public struct ControlCenterSlider: View {
    let fraction: Double
    let level: QuotaLevel
    let brandColor: Color
    let leftIcon: String
    let label: String
    let rightText: String
    
    public init(
        fraction: Double,
        level: QuotaLevel,
        brandColor: Color,
        leftIcon: String = "timer",
        label: String = "5 小時用量限制",
        rightText: String = ""
    ) {
        self.fraction = max(0.0, min(1.0, fraction))
        self.level = level
        self.brandColor = brandColor
        self.leftIcon = leftIcon
        self.label = label
        self.rightText = rightText
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 頂部欄：左側標籤 + 右側數值
            HStack {
                Label(label, systemImage: leftIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(rightText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(level.color)
            }
            
            // 粗大膠囊滑塊主體
            GeometryReader { geometry in
                let width = geometry.size.width
                let fillWidth = max(6, width * CGFloat(fraction))
                
                ZStack(alignment: .leading) {
                    // 1. 底層凹陷質感軌道
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                    
                    // 2. 刻度線標記 (Notches: 20% 與 50%)
                    Rectangle()
                        .fill(Color.primary.opacity(0.18))
                        .frame(width: 1.5, height: 16)
                        .offset(x: width * 0.5)
                    
                    Rectangle()
                        .fill(Color.primary.opacity(0.18))
                        .frame(width: 1.5, height: 16)
                        .offset(x: width * 0.2)
                    
                    // 3. 飽滿平滑漸層填充膠囊
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [brandColor, level.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth, height: 18)
                        .shadow(color: level.color.opacity(fraction > 0.08 ? 0.35 : 0), radius: 3, x: 0, y: 1)
                        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: fraction)
                }
            }
            .frame(height: 18)
        }
    }
}

/// 兼容舊版 QuotaProgressBar
public struct QuotaProgressBar: View {
    let fraction: Double
    let level: QuotaLevel
    let brandColor: Color
    
    public init(fraction: Double, level: QuotaLevel, brandColor: Color) {
        self.fraction = max(0.0, min(1.0, fraction))
        self.level = level
        self.brandColor = brandColor
    }
    
    public var body: some View {
        ControlCenterSlider(
            fraction: fraction,
            level: level,
            brandColor: brandColor,
            leftIcon: "timer",
            label: "5 小時用量限制",
            rightText: "\(Int(fraction * 100))%"
        )
    }
}

/// Apple 控制中心風格：彩色應用圖示方塊徽章 (App Icon Badge)
public struct ControlCenterIconBadge: View {
    let provider: ProviderType
    let size: CGFloat
    
    public init(provider: ProviderType, size: CGFloat = 32) {
        self.provider = provider
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(provider.brandGradient)
                .shadow(color: provider.brandColor.opacity(0.35), radius: 3, x: 0, y: 1.5)
            
            Image(systemName: provider.iconName)
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

/// Apple 控制中心風格：圓形按鈕 (Circle Button)
public struct ControlCenterCircleButton: View {
    let iconName: String
    let helpText: String
    var isRotating: Bool = false
    let action: () -> Void
    
    public init(iconName: String, helpText: String = "", isRotating: Bool = false, action: @escaping () -> Void) {
        self.iconName = iconName
        self.helpText = helpText
        self.isRotating = isRotating
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                    .animation(isRotating ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRotating)
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}

/// 狀態指示小點
public struct StatusDot: View {
    let level: QuotaLevel
    
    public init(level: QuotaLevel) {
        self.level = level
    }
    
    public var body: some View {
        Circle()
            .fill(level.color)
            .frame(width: 7, height: 7)
            .shadow(color: level.color.opacity(0.4), radius: 2)
    }
}


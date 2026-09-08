import SwiftUI

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
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景軌道
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 8)
                
                // 50% 刻度線
                Rectangle()
                    .fill(Color.primary.opacity(0.25))
                    .frame(width: 1.5, height: 8)
                    .offset(x: geometry.size.width * 0.5)
                
                // 20% 刻度線
                Rectangle()
                    .fill(Color.primary.opacity(0.25))
                    .frame(width: 1.5, height: 8)
                    .offset(x: geometry.size.width * 0.2)
                
                // 進度條
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            colors: [brandColor, level.color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, geometry.size.width * CGFloat(fraction)), height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: fraction)
            }
        }
        .frame(height: 8)
    }
}

public struct StatusDot: View {
    let level: QuotaLevel
    
    public init(level: QuotaLevel) {
        self.level = level
    }
    
    public var body: some View {
        Circle()
            .fill(level.color)
            .frame(width: 8, height: 8)
            .shadow(color: level.color.opacity(0.5), radius: 3)
    }
}

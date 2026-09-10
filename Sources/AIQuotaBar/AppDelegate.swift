import AppKit
import SwiftUI

// 自訂 HostingView 與 HostingController 以保證 NSPopover 內部的 SwiftUI ScrollView 能順暢轉發觸控板與滾輪事件
final class PopoverHostingView<Content: View>: NSHostingView<Content> {
    override func wantsForwardedScrollEvents(for axis: NSEvent.GestureAxis) -> Bool {
        return true
    }
}

final class PopoverHostingController<Content: View>: NSHostingController<Content> {
    override func loadView() {
        self.view = PopoverHostingView(rootView: rootView)
    }
}

@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // 設定為 Menu Bar 常駐 Accessory App（不佔 Dock 圖示）
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // 建立 StatusItem
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            updateStatusItemUI()
        }
        
        // 建立 Popover
        let hostingController = PopoverHostingController(rootView: MenuBarView())
        hostingController.preferredContentSize = NSSize(width: 410, height: 600)
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 410, height: 600)
        popover.behavior = .transient
        popover.contentViewController = hostingController
        
        // 監聽 QuotaManager 更新
        QuotaManager.shared.onQuotaUpdated = { [weak self] in
            DispatchQueue.main.async {
                self?.updateStatusItemUI()
            }
        }
        
        // 啟動 QuotaManager 輪詢排程
        QuotaManager.shared.start()
        
        // 監聽點擊外部事件以關閉 Popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            // 每次顯示前確保 contentSize 一致，避免初次點開或切換尺寸時頂部邊緣被截斷
            popover.contentSize = NSSize(width: 410, height: 600)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApplication.shared.activate(ignoringOtherApps: true)
            // 讓 popover 視窗獲得 Key 焦點，確保第一時間能順暢接收觸控板與滑鼠滾輪滾動
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    public func updateStatusItemUI() {
        guard let button = statusItem.button else { return }
        
        let manager = QuotaManager.shared
        let config = AppConfig.shared
        let minPercent = manager.minRemainingPercentage
        
        // 根據樣式設定標題與圖示
        let icon = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.50percent", accessibilityDescription: "AI Quota")
        icon?.isTemplate = true
        button.image = icon
        button.imagePosition = .imageLeading
        
        switch config.statusBarStyle {
        case "iconOnly":
            button.title = ""
        case "iconAndCountdown":
            if let countdown = manager.earliestResetCountdown {
                button.title = " \(countdown)"
            } else {
                button.title = " \(minPercent)%"
            }
        default: // iconAndPercent
            button.title = " \(minPercent)%"
        }
    }
}

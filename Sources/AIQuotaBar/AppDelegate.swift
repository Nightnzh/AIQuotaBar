import AppKit
import SwiftUI

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
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
        
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
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApplication.shared.activate(ignoringOtherApps: true)
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

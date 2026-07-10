import AppKit
import SwiftUI

@MainActor
enum AppPresentation {
    static func showMainWindow(using openWindow: OpenWindowAction) {
        prepareForWindowPresentation()
        openWindow(id: "main")
        activateOnNextRunLoop()
    }

    static func showSettings(using openSettings: OpenSettingsAction) {
        prepareForWindowPresentation()
        openSettings()
        activateOnNextRunLoop()
    }

    static func mainWindowDidAppear() {
        prepareForWindowPresentation()
    }

    static func mainWindowDidDisappear(store: AppStore) {
        DispatchQueue.main.async {
            if store.settings.keepRunningAfterMainWindowClose {
                updateActivationPolicy(store: store)
            } else {
                NSApp.terminate(nil)
            }
        }
    }

    static func settingsDidAppear() {
        prepareForWindowPresentation()
    }

    static func settingsDidDisappear(store: AppStore) {
        DispatchQueue.main.async {
            updateActivationPolicy(store: store)
        }
    }

    static func updateActivationPolicy(store: AppStore) {
        let shouldHideDock = store.settings.hideDockIconInMenuBarMode && !hasVisibleAppWindow
        let targetPolicy: NSApplication.ActivationPolicy = shouldHideDock ? .accessory : .regular
        if NSApp.activationPolicy() != targetPolicy {
            NSApp.setActivationPolicy(targetPolicy)
        }
    }

    private static func prepareForWindowPresentation() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
    }

    private static func activateOnNextRunLoop() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private static var hasVisibleAppWindow: Bool {
        NSApp.windows.contains { window in
            (window.isVisible || window.isMiniaturized) && window.canBecomeMain
        }
    }
}

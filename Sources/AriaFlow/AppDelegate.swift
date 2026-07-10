import AppKit

@MainActor
final class AriaFlowAppDelegate: NSObject, NSApplicationDelegate {
    private weak var store: AppStore?
    private var pendingURLs: [URL] = []
    private var pendingMainWindowRequest = false
    private var showMainWindow: (() -> Void)?
    private var statusItemEventMonitor: Any?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseUp]
        ) { [weak self] event in
            guard event.window?.level == .statusBar else { return event }
            if event.type == .leftMouseDown {
                self?.requestMainWindow()
            }
            return nil
        }
    }

    func configure(store: AppStore, showMainWindow: @escaping () -> Void) {
        self.store = store
        self.showMainWindow = showMainWindow
        if pendingMainWindowRequest {
            pendingMainWindowRequest = false
            showMainWindow()
        }
        flushPendingURLs()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let store else {
            pendingURLs.append(contentsOf: urls)
            return
        }

        requestMainWindow()
        handle(urls, store: store)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        application(sender, open: [URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        application(sender, open: filenames.map(URL.init(fileURLWithPath:)))
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        store?.stopEngineForAppTermination()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let statusItemEventMonitor {
            NSEvent.removeMonitor(statusItemEventMonitor)
            self.statusItemEventMonitor = nil
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            requestMainWindow()
        }
        return true
    }

    private func flushPendingURLs() {
        guard let store, !pendingURLs.isEmpty else { return }
        let urls = pendingURLs
        pendingURLs.removeAll()
        requestMainWindow()
        handle(urls, store: store)
    }

    private func handle(_ urls: [URL], store: AppStore) {
        for url in urls {
            if url.isFileURL, url.pathExtension.lowercased() == "torrent" {
                Task {
                    await ensureConnected(store)
                    await store.addTorrentTask(fileURL: url, splitCount: store.settings.splitCount)
                }
                continue
            }

            if let scheme = url.scheme?.lowercased(), ["magnet", "ed2k"].contains(scheme) {
                Task {
                    await ensureConnected(store)
                    await store.addURLTask(urlText: url.absoluteString, fileName: "", splitCount: store.settings.splitCount)
                }
            }
        }
    }

    private func ensureConnected(_ store: AppStore) async {
        if store.connectionState != .connected {
            await store.retryEngineConnection()
        }
    }

    private func requestMainWindow() {
        guard let showMainWindow else {
            pendingMainWindowRequest = true
            return
        }
        showMainWindow()
    }
}

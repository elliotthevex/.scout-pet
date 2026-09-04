import Cocoa
import WebKit

let petDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".scout-pet")
let petHTML = petDir.appendingPathComponent("pet.html")

class PetPanel: NSPanel {
    override var canBecomeKey: Bool { return false }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: PetPanel!
    var statusItem: NSStatusItem!
    var webView: WKWebView!
    var pollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let width: CGFloat = 150
        let height: CGFloat = 165
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let sf = screen.visibleFrame
        let x = sf.maxX - width - 24
        let y = sf.maxY - height - 24
        let rect = NSRect(x: x, y: y, width: width, height: height)

        window = PetPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = true

        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height), configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        if #available(macOS 13.0, *) {
            webView.underPageBackgroundColor = .clear
        }
        webView.loadFileURL(petHTML, allowingReadAccessTo: petDir)

        window.contentView = webView
        window.orderFrontRegardless()

        setupStatusItem()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pushLocalState()
        }
    }

    let projectsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
    let activityWindow: TimeInterval = 6

    // Fast, local-only signal: did THIS/any conversation's transcript get written
    // to very recently. Great for immediate feedback, but misses long silent
    // gaps inside a single tool call (a session can be busy for many minutes
    // with zero file writes), so it's combined with the authoritative signal below.
    func recentTranscriptActivity() -> Bool {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: projectsDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return false }

        let cutoff = Date().addingTimeInterval(-activityWindow)
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modDate = values.contentModificationDate else { continue }
            if modDate > cutoff { return true }
        }
        return false
    }

    // Authoritative signal for OTHER sessions: refreshed periodically (via a
    // /loop tick) into sessions.json as {"updatedAt": <ms>, "anyOtherRunning": bool}.
    // Ignored if stale, so a stopped loop degrades to local-only detection
    // instead of getting stuck showing "sitting" forever.
    let sessionsStaleAfter: TimeInterval = 150

    func otherSessionsRunning() -> Bool {
        guard let text = try? String(contentsOf: petDir.appendingPathComponent("sessions.json"), encoding: .utf8),
              let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        guard let updatedAtMs = obj["updatedAt"] as? Double else { return false }
        let ageSeconds = Date().timeIntervalSince1970 - (updatedAtMs / 1000.0)
        guard ageSeconds >= 0, ageSeconds < sessionsStaleAfter else { return false }
        return (obj["anyOtherRunning"] as? Bool) ?? false
    }

    func anyClaudeSessionActive() -> Bool {
        return recentTranscriptActivity() || otherSessionsRunning()
    }

    func pushLocalState() {
        let state = anyClaudeSessionActive() ? "working" : "idle"
        let statusJS = "(function(){ window.scoutSetStatus && window.scoutSetStatus('\(state)'); })();"
        webView.evaluateJavaScript(statusJS, completionHandler: nil)

        if let eventsText = try? String(contentsOf: petDir.appendingPathComponent("events.json"), encoding: .utf8),
           !eventsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let js = "(function(){try{ window.scoutSetEvents && window.scoutSetEvents(\(eventsText)); }catch(e){}})();"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "🐾"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Scout", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        let reloadItem = NSMenuItem(title: "Reload", action: #selector(reload), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)
        let quitItem = NSMenuItem(title: "Quit Scout", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc func reload() {
        webView.loadFileURL(petHTML, allowingReadAccessTo: petDir)
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

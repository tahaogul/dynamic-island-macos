import AppKit
import SwiftUI

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var islandController: IslandWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        islandController = IslandWindowController()
        islandController.showWindow(nil)
        VoiceAssistant.shared.setupGlobalHotkey()
    }
}

// MARK: - Launch

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

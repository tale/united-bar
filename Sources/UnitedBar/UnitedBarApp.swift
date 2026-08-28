import AppKit
import SwiftUI

@main
struct UnitedBarApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("United Bar", systemImage: "airplane") {
            TrackerView()
        }
        .menuBarExtraStyle(.window)
    }
}

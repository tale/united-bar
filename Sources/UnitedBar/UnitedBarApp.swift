import AppKit
import SwiftUI

@main
struct UnitedBarApp: App {
    private let store = FlightStore()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("United Bar", systemImage: "airplane") {
            TrackerView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

import AppKit
import SwiftUI

@main
struct UnitedBarApp: App {
  private let store = FlightStore()

  init() {
    NSApplication.shared.setActivationPolicy(.accessory)
  }

  var body: some Scene {
    MenuBarExtra {
      TrackerView(store: store)
    } label: {
      MenuBarLabel(store: store)
    }
    .menuBarExtraStyle(.window)
  }
}

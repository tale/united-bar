import AppKit
import SwiftUI

struct TrackerView: View {
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                Image(systemName: "airplane")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.tertiary)

                Text("No flight data")
                    .font(.headline)

                Text("Join United WiFi to read the flight feed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)

            Divider()

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 260)
    }
}

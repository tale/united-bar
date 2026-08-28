import AppKit
import SwiftUI

struct TrackerView: View {
  let store: FlightStore

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      Divider()
      content
      Divider()
      footer
    }
    .padding(12)
    .frame(width: 440)
    .task { await store.refresh() }
  }

  private var header: some View {
    HStack {
      Label("Flight Info", systemImage: "airplane").font(.headline)
      Spacer()

      if store.isLoading {
        ProgressView().controlSize(.small)
      }

      Button("Refresh") {
        Task { await store.refresh() }
      }
      .disabled(store.isLoading)
    }
  }

  @ViewBuilder
  private var content: some View {
    if let errorText = store.errorText {
      VStack(alignment: .leading, spacing: 4) {
        Text("Request failed").font(.subheadline.bold())
        Text(errorText).font(.callout).foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      ScrollView {
        Text(store.payloadText)
          .font(.system(size: 11, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(height: 360)
    }
  }

  private var footer: some View {
    HStack {
      if let fetchedDatetime = store.fetchedDatetime {
        Text(
          "Updated \(fetchedDatetime.formatted(date: .omitted, time: .standard))"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Spacer()
      Button("Quit") { NSApp.terminate(nil) }
        .buttonStyle(.plain)
        .keyboardShortcut("q")
        .foregroundStyle(.secondary)
    }
  }
}

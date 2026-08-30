import AppKit
import SwiftUI

struct MenuBarLabel: View {
  let store: FlightStore

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "airplane")

      if let info = store.info {
        Text(verbatim: summary(for: info))
      }
    }
    .task { store.startPolling() }
  }

  private func summary(for info: FlightInfo) -> String {
    let remaining = info.timeRemaining.formatted(hoursMinutes)
    return
      "\(info.origin.airportCode) → \(info.destination.airportCode) \(remaining)"
  }
}

struct TrackerView: View {
  let store: FlightStore

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      content
      footer
    }
    .padding(16)
    .frame(width: store.info == nil ? 320 : 440)
  }

  @ViewBuilder
  private var content: some View {
    if let info = store.info {
      FlightPanel(info: info, aircraftImageData: store.aircraftImageData)
    } else if let errorText = store.errorText {
      placeholder {
        Image(systemName: "antenna.radiowaves.left.and.right.slash")
          .font(.system(size: 26, weight: .medium))
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(.secondary)

        Text(verbatim: "No flight data")
          .font(.system(size: 15, weight: .semibold, design: .rounded))

        Text(verbatim: errorText)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
    } else {
      placeholder {
        ProgressView().controlSize(.small)

        Text(verbatim: "Looking for your flight")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
    }
  }

  private func placeholder(
    @ViewBuilder _ body: () -> some View
  ) -> some View {
    VStack(spacing: 8) {
      body()
    }
    .frame(maxWidth: .infinity, minHeight: 132)
    .padding(.horizontal, 18)
  }

  private var footer: some View {
    HStack(spacing: 8) {
      if store.isLoading {
        ProgressView().controlSize(.mini)
      } else if let fetchedDatetime = store.fetchedDatetime {
        Text(verbatim: "Updated \(fetchedDatetime.formatted(clock))")
          .font(.system(size: 11))
          .foregroundStyle(.tertiary)
      }

      Spacer()

      Button("Refresh") { Task { await store.refresh() } }
        .disabled(store.isLoading)

      Button("Quit") { NSApp.terminate(nil) }
        .keyboardShortcut("q")
    }
    .buttonStyle(.plain)
    .font(.system(size: 12))
    .foregroundStyle(.secondary)
  }
}

private struct FlightPanel: View {
  let info: FlightInfo
  let aircraftImageData: Data?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      identity
      countdown
      route
      telemetry.padding(.top, 8)
    }
  }

  private var identity: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(verbatim: info.callSign)
        .font(.system(size: 18, weight: .bold, design: .rounded))

      Text(verbatim: "\(info.aircraftModel) · \(info.tailNumber)")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)

      Spacer()

      Text(verbatim: info.statusPhase)
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .glassCapsule(tint: accent)

    }
  }

  @ViewBuilder
  private var render: some View {
    if let aircraftImageData, let image = NSImage(data: aircraftImageData) {
      Image(nsImage: image)
        .resizable()
        .scaledToFit()
    } else {
      Image(systemName: "airplane")
        .font(.system(size: 30))
        .foregroundStyle(.quaternary)
    }
  }

  private var countdown: some View {
    HStack(alignment: .center, spacing: 12) {
      remaining
      Spacer(minLength: 8)
      render.frame(width: 172, height: 54)
    }
  }

  private var remaining: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(verbatim: "Remaining")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.tertiary)
        .textCase(.uppercase)

      Text(verbatim: info.timeRemaining.formatted(hoursMinutes))
        .font(.system(size: 34, weight: .bold, design: .rounded))
        .monospacedDigit()
        .contentTransition(.numericText())
        .animation(.snappy, value: info.timeRemaining)

      HStack(spacing: 5) {
        Text(verbatim: "Arrives \(info.destination.estimated.formatted(clock))")
          .foregroundStyle(.secondary)

        if info.arrivalDelay > .zero {
          Text(verbatim: "· \(info.arrivalDelay.formatted(hoursMinutes)) late")
            .foregroundStyle(.orange)
        }
      }
      .font(.system(size: 13, weight: .medium))
    }
  }

  private var route: some View {
    VStack(spacing: 8) {
      HStack(spacing: 12) {
        Text(verbatim: info.origin.airportCode)
        routeBar
        Text(verbatim: info.destination.airportCode)
      }
      .font(.system(size: 17, weight: .semibold, design: .rounded))

      HStack(alignment: .top) {
        endpoint(info.origin, showing: departure, alignment: .leading)
        Spacer(minLength: 12)
        endpoint(
          info.destination, showing: info.destination.estimated,
          alignment: .trailing)
      }
    }
  }

  private var routeBar: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let flown = min(max(width * info.progress, 0), width)

      ZStack(alignment: .leading) {
        Capsule()
          .fill(.quaternary)
          .frame(height: 4)

        Capsule()
          .fill(
            LinearGradient(
              colors: [accent.opacity(0.45), accent],
              startPoint: .leading, endPoint: .trailing)
          )
          .frame(width: flown, height: 4)

        Image(systemName: "airplane")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.primary)
          .offset(x: min(max(flown - 8, 0), width - 16))
      }
      .frame(height: 20)
      .animation(.snappy, value: info.progress)
    }
    .frame(height: 20)
  }

  private func endpoint(
    _ endpoint: FlightInfo.Endpoint, showing instant: FlightInfo.Instant,
    alignment: HorizontalAlignment
  ) -> some View {
    VStack(alignment: alignment, spacing: 1) {
      HStack(spacing: 5) {
        Text(verbatim: instant.formatted(clock))
          .font(.system(size: 14, weight: .semibold).monospacedDigit())

        if instant.date != endpoint.scheduled.date {
          Text(verbatim: endpoint.scheduled.formatted(clock))
            .font(.system(size: 11).monospacedDigit())
            .foregroundStyle(.tertiary)
            .strikethrough()
        }
      }

      Text(verbatim: place(endpoint))
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
  }

  private var telemetry: some View {
    HStack(alignment: .center, spacing: 16) {
      Grid(horizontalSpacing: 14, verticalSpacing: 11) {
        GridRow {
          tile("Altitude", rounded(altitude, usage: .asProvided))
          tile("Ground", rounded(info.groundSpeed, usage: .general))
        }
        GridRow {
          tile("Air speed", rounded(info.airSpeed, usage: .general))
          tile("Outside", rounded(info.airTemperature, usage: .general))
        }
      }

      compass
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 14)
    .glassPanel()
  }

  private var compass: some View {
    VStack(spacing: 5) {
      Text(verbatim: "WIND")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.secondary)

      ZStack {
        Circle().stroke(.quaternary, lineWidth: 1)

        Text(verbatim: "N")
          .font(.system(size: 8, weight: .heavy))
          .foregroundStyle(.tertiary)
          .offset(y: -19)

        if let bearing = info.windBearing {
          Image(systemName: "arrowtriangle.up.fill")
            .font(.system(size: 8))
            .foregroundStyle(.primary)
            .offset(y: -12)
            .rotationEffect(.degrees(bearing))
            .animation(.snappy, value: bearing)
        }
      }
      .frame(width: 46, height: 46)

      Text(
        verbatim:
          "\(info.windDirection) \(rounded(info.windSpeed, usage: .general))"
      )
      .font(.system(size: 12, weight: .semibold, design: .rounded))
      .monospacedDigit()
      .lineLimit(1)
      .minimumScaleFactor(0.7)
    }
    .frame(width: 84)
  }

  private func tile(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(verbatim: label.uppercased())
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.secondary)

      Text(verbatim: value)
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .contentTransition(.numericText())
        .animation(.snappy, value: value)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var accent: Color {
    info.arrivalDelay > .zero ? .orange : .accentColor
  }

  private var altitude: Measurement<UnitLength> {
    Locale.current.measurementSystem == .metric
      ? info.altitude.converted(to: .meters)
      : info.altitude.converted(to: .feet)
  }

  private var departure: FlightInfo.Instant {
    info.origin.actual ?? info.origin.scheduled
  }

  private func place(_ endpoint: FlightInfo.Endpoint) -> String {
    [endpoint.terminal, endpoint.gate.isEmpty ? "" : "Gate \(endpoint.gate)"]
      .filter { !$0.isEmpty }
      .joined(separator: " · ")
  }
}

extension FlightInfo.Instant {
  fileprivate func formatted(_ style: Date.FormatStyle) -> String {
    var local = style
    local.timeZone = timeZone
    return date.formatted(local)
  }
}

private func rounded<UnitType: Dimension>(
  _ value: Measurement<UnitType>, usage: MeasurementFormatUnitUsage<UnitType>
) -> String {
  value.formatted(
    .measurement(
      width: .abbreviated, usage: usage,
      numberFormatStyle: .number.precision(.fractionLength(0))))
}

private let clock = Date.FormatStyle.dateTime.hour().minute()
private let hoursMinutes = Duration.UnitsFormatStyle(
  allowedUnits: [.hours, .minutes], width: .narrow)

extension View {
  @ViewBuilder
  fileprivate func glassCapsule(tint: Color) -> some View {
    if #available(macOS 26, *) {
      glassEffect(.regular.tint(tint.opacity(0.35)), in: .capsule)
    } else {
      background(tint.opacity(0.18), in: .capsule)
    }
  }

  @ViewBuilder
  fileprivate func glassPanel() -> some View {
    if #available(macOS 26, *) {
      glassEffect(.regular, in: .rect(cornerRadius: 14))
    } else {
      background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 14))
    }
  }
}

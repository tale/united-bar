import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class FlightStore {
  private(set) var info: FlightInfo?
  private(set) var aircraftImageData: Data?
  private(set) var errorText: String?
  private(set) var isLoading = false
  private(set) var fetchedDatetime: Date?
  private var pollTask: Task<Void, Never>?
  private var imagedEquipmentCode: String?

  private static let endpoint = URL(
    string: "https://www.unitedwifi.com/api/flight/portal/v1/flifo")!
  private static let pollInterval = Duration.seconds(60)

  func startPolling() {
    guard pollTask == nil else { return }

    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.refresh()
        try? await Task.sleep(for: FlightStore.pollInterval)
      }
    }
  }

  func refresh() async {
    isLoading = true
    defer { isLoading = false }

    do {
      let fetched = try await fetchInfo()
      info = fetched
      fetchedDatetime = Date()
      errorText = nil

      let remaining = fetched.timeRemaining.formatted(
        .units(allowed: [.hours, .minutes], width: .narrow))

      Logger.flight.info(
        """
        \(fetched.callSign, privacy: .public) \
        \(fetched.origin.airportCode, privacy: .public)→\
        \(fetched.destination.airportCode, privacy: .public) \
        \(fetched.equipmentCode, privacy: .public) \
        \(remaining, privacy: .public) remaining
        """)

      await loadAircraftImage(for: fetched)
    } catch {
      errorText =
        (error as? DecodingError).map { "Unexpected payload: \($0)" }
        ?? error.localizedDescription

      Logger.flight.error(
        "flifo failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func loadAircraftImage(for info: FlightInfo) async {
    guard imagedEquipmentCode != info.equipmentCode else { return }
    guard
      let url = await AircraftManifest.shared.url(
        equipmentCode: info.equipmentCode)
    else {
      Logger.flight.error(
        "no render for equipment \(info.equipmentCode, privacy: .public)")
      return
    }

    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      aircraftImageData = data
      imagedEquipmentCode = info.equipmentCode
      Logger.flight.info(
        """
        render \(url.lastPathComponent, privacy: .public) \
        \(data.count, privacy: .public) bytes
        """)
    } catch {
      Logger.flight.error(
        """
        render \(url.lastPathComponent, privacy: .public) failed: \
        \(error.localizedDescription, privacy: .public)
        """)
    }
  }

  private func fetchInfo() async throws -> FlightInfo {
    var request = URLRequest(url: Self.endpoint)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.cachePolicy = .reloadIgnoringLocalCacheData

    let (data, response) = try await URLSession.shared.data(for: request)

    // On the ground the endpoint redirects to United's in-flight marketing page
    // which returns a 200 but with HTML, so we need to treat it as an error
    guard let http = response as? HTTPURLResponse,
      http.statusCode == 200,
      let contentType = http.value(forHTTPHeaderField: "Content-Type"),
      contentType.localizedCaseInsensitiveContains("json")
    else {
      throw FetchError.unavailable
    }

    return try JSONDecoder().decode(FlightInfo.self, from: data)
  }

  enum FetchError: LocalizedError {
    case unavailable

    var errorDescription: String? {
      "Flight data is unavailable. Connect to the aircraft network."
    }
  }
}

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

      let remaining =
        fetched.timeRemaining?.formatted(
          .units(allowed: [.hours, .minutes], width: .narrow)) ?? "unknown"

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
    let candidates = await AircraftManifest.shared.urls(
      equipmentCode: info.equipmentCode)

    guard !candidates.isEmpty else {
      Logger.flight.error(
        "no render for equipment \(info.equipmentCode, privacy: .public)")
      return
    }

    for url in candidates {
      do {
        let data = try await Self.render(from: url)
        aircraftImageData = data
        imagedEquipmentCode = info.equipmentCode

        Logger.flight.info(
          """
          render \(url.lastPathComponent, privacy: .public) \
          \(data.count, privacy: .public) bytes
          """)

        return
      } catch {
        Logger.flight.error(
          """
          render \(url.lastPathComponent, privacy: .public) failed: \
          \(error.localizedDescription, privacy: .public)
          """)
      }
    }
  }

  private static func render(from url: URL) async throws -> Data {
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse,
      http.statusCode == 200,
      let contentType = http.value(forHTTPHeaderField: "Content-Type"),
      contentType.localizedCaseInsensitiveContains("image")
    else {
      throw FetchError.notAnImage
    }

    return data
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

    let decoded = try JSONDecoder().decode(FlightInfo.self, from: data)
    if decoded.flightNumber.isEmpty {
      throw FetchError.illegalData
    }

    return decoded
  }

  enum FetchError: LocalizedError {
    case unavailable
    case illegalData
    case notAnImage

    var errorDescription: String? {
      switch self {
      case .unavailable: "Flight data is unavailable. Connect to Unitedwifi.com"
      case .illegalData:
        "Invalid flight data recieved, this aircraft may be experiencing connectivity issues."
      case .notAnImage: "The portal served something that isn't an image"
      }
    }
  }
}

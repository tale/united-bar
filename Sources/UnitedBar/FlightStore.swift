import Foundation
import Observation

@MainActor
@Observable
final class FlightStore {
  private(set) var info: FlightInfo?
  private(set) var errorText: String?
  private(set) var isLoading = false
  private(set) var fetchedDatetime: Date?
  private var pollTask: Task<Void, Never>?

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
      info = try await fetchInfo()
      fetchedDatetime = Date()
      errorText = nil
    } catch {
      errorText =
        (error as? DecodingError).map { "Unexpected payload: \($0)" }
        ?? error.localizedDescription
    }
  }

  private func fetchInfo() async throws -> FlightInfo {
    var request = URLRequest(url: Self.endpoint)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.cachePolicy = .reloadIgnoringLocalCacheData

    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode(FlightInfo.self, from: data)
  }
}

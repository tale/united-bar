import Foundation
import Observation

@MainActor
@Observable
final class FlightStore {
  private(set) var payloadText = ""
  private(set) var errorText: String?
  private(set) var isLoading = false
  private(set) var fetchedDatetime: Date?

  private static let endpoint = URL(
    string: "https://www.unitedwifi.com/api/flight/portal/v1/flifo")!

  func refresh() async {
    isLoading = true
    defer { isLoading = false }

    do {
      payloadText = try await fetchPayloadText()
      fetchedDatetime = Date()
      errorText = nil
    } catch {
      errorText = error.localizedDescription
    }
  }

  private func fetchPayloadText() async throws -> String {
    var request = URLRequest(url: Self.endpoint)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.cachePolicy = .reloadIgnoringLocalCacheData

    let (data, _) = try await URLSession.shared.data(for: request)
    let payload = try JSONSerialization.jsonObject(with: data)
    let pretty = try JSONSerialization.data(
      withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])

    return String(decoding: pretty, as: UTF8.self)
  }
}

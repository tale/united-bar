import Foundation

struct SessionData {
  let wifi: Wifi
  let flight: FlightInfo
  let weather: Weather?
  let portalVersion: String

  struct Wifi {
    let isPortalInitialized: Bool
    let isOfferedOnFlight: Bool
    let isConnectionAvailable: Bool
    let isPDEAvailable: Bool
    let isLoggedIn: Bool
    let isSubscriptionAvailable: Bool
    let isPurchaseActive: Bool
    let shouldShowCoverage: Bool
    let vendorCode: String
    let vendorName: String
    let coverageMessage: String
    let access: Access?
  }

  struct Access {
    let type: String
    let tier: String
    let tierSummary: String
    let fulfilmentState: String
    let orderState: String
    let timeRemaining: Int
  }

  struct Weather {
    let current: Conditions?
    let forecast: [Conditions]
  }

  struct Conditions {
    let day: String
    let summary: String
    let code: Int?
    let temperature: Measurement<UnitTemperature>?
    let high: Measurement<UnitTemperature>?
    let low: Measurement<UnitTemperature>?
  }
}

extension SessionData.Wifi {
  var isAvailable: Bool {
    isOfferedOnFlight && isConnectionAvailable
  }

  enum Connection {
    case unavailable
    case offline
    case signIn
    case purchase
    case connected
  }

  var connection: Connection {
    guard isOfferedOnFlight else { return .unavailable }
    guard isConnectionAvailable else { return .offline }
    guard isLoggedIn else { return .signIn }
    guard isEntitled else { return .purchase }

    return .connected
  }

  private var isEntitled: Bool {
    guard let access else { return false }
    return access.fulfilmentState.caseInsensitiveCompare("ACTIVE")
      == .orderedSame
  }
}

extension SessionData: Decodable {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    wifi = try Wifi(from: decoder)
    flight = try container.decode(FlightInfo.self, forKey: .flifo)
    weather = try? container.decode(Weather.self, forKey: .weather)
    portalVersion = container.text(.version)
  }

  private enum CodingKeys: String, CodingKey {
    case flifo, weather, version
  }
}

extension SessionData.Wifi: Decodable {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    isPortalInitialized = container.flag(.isPortalInitialized)
    isOfferedOnFlight = container.flag(.flightOffersInternetService)
    isConnectionAvailable = container.flag(.internetConnectionIsAvailable)
    isPDEAvailable = container.flag(.isPDEServiceAvailable)
    isLoggedIn = container.flag(.IsLoggedIn)
    isSubscriptionAvailable = container.flag(.isSubscriptionAvailable)
    isPurchaseActive = container.flag(.PurchaseActive)
    shouldShowCoverage = container.flag(.ShowCoverageArea)

    vendorCode = container.text(.VendorCode)
    vendorName = container.text(.VendorName)
    coverageMessage = container.text(.CoverageMessage)
    access = try? container.decode(SessionData.Access.self, forKey: .internet)
  }

  private enum CodingKeys: String, CodingKey {
    case isPortalInitialized, flightOffersInternetService
    case internetConnectionIsAvailable, isPDEServiceAvailable
    case IsLoggedIn, isSubscriptionAvailable, PurchaseActive
    case ShowCoverageArea, VendorCode, VendorName, CoverageMessage
    case internet
  }
}

extension SessionData.Access: Decodable {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    type = container.text(.accessType)
    tier = container.text(.tier)
    tierSummary = container.text(.tierDescription)
    fulfilmentState = container.text(.fulfilmentState)
    orderState = container.text(.orderState)
    timeRemaining = container.number(.timeRemaining) ?? 0
  }

  private enum CodingKeys: String, CodingKey {
    case accessType, tier, tierDescription, fulfilmentState, orderState
    case timeRemaining
  }
}

extension SessionData.Weather: Decodable {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    current = try? container.decode(
      SessionData.Conditions.self, forKey: .currently)

    let days = (try? container.decode([Day].self, forKey: .forecast)) ?? []
    forecast = days.compactMap(\.conditions)
  }

  private struct Day: Decodable {
    let conditions: SessionData.Conditions?
    init(from decoder: Decoder) throws {
      conditions = try? SessionData.Conditions(from: decoder)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case currently, forecast
  }
}

extension SessionData.Conditions: Decodable {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    day = container.text(.day)
    summary = container.text(.text)
    code = container.number(.code)
    temperature = container.celsius(.currtempc)
    high = container.celsius(.hightempc)
    low = container.celsius(.lowtempc)
  }

  private enum CodingKeys: String, CodingKey {
    case day, text, code, currtempc, hightempc, lowtempc
  }
}

// I think this is an effective way to handle the weird types
extension KeyedDecodingContainer {
  fileprivate func flag(_ key: Key) -> Bool {
    if let value = try? decode(Bool.self, forKey: key) {
      return value
    }

    return (try? decode(String.self, forKey: key))
      .map { $0.caseInsensitiveCompare("true") == .orderedSame } ?? false
  }

  fileprivate func text(_ key: Key) -> String {
    (try? decode(String.self, forKey: key)) ?? ""
  }

  fileprivate func number(_ key: Key) -> Int? {
    if let value = try? decode(Int.self, forKey: key) {
      return value
    }

    return (try? decode(String.self, forKey: key)).flatMap(Int.init)
  }

  fileprivate func celsius(_ key: Key) -> Measurement<UnitTemperature>? {
    if let value = try? decode(Double.self, forKey: key) {
      return Measurement(value: value, unit: .celsius)
    }

    return (try? decode(String.self, forKey: key))
      .flatMap(Double.init)
      .map { Measurement(value: $0, unit: .celsius) }
  }
}

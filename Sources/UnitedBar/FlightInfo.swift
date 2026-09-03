import Foundation

struct FlightInfo {
  let airlineCode: String
  let flightNumber: String
  let status: String
  let isFake: Bool

  let aircraftModel: String
  let equipmentCode: String
  let noseNumber: String
  let tailNumber: String

  let origin: Endpoint
  let destination: Endpoint

  let flightDuration: Duration?
  let timeRemaining: Duration?

  let airSpeed: Measurement<UnitSpeed>?
  let groundSpeed: Measurement<UnitSpeed>?
  let altitude: Measurement<UnitLength>?
  let airTemperature: Measurement<UnitTemperature>?
  let windSpeed: Measurement<UnitSpeed>?
  let windDirection: String

  struct Endpoint {
    let airportCode: String
    let cityState: String
    let summary: String
    let terminal: String
    let concourse: String
    let gate: String
    let scheduled: Instant?
    let estimated: Instant?
    let actual: Instant?
    var current: Instant? { actual ?? estimated ?? scheduled }
  }

  struct Instant {
    let date: Date
    let timeZone: TimeZone
  }
}

extension FlightInfo {
  var callSign: String {
    [airlineCode, flightNumber].filter { !$0.isEmpty }.joined(separator: " ")
  }

  var progress: Double {
    guard let flightDuration, let timeRemaining else { return 0 }
    let total = Double(flightDuration.components.seconds)
    guard total > 0 else { return 0 }

    let flown = total - Double(timeRemaining.components.seconds)
    return min(max(flown / total, 0), 1)
  }

  // United gives status as "<Phase> - <Description>" so we can probably split.
  var statusPhase: String {
    status.components(separatedBy: " - ").first ?? status
  }

  var windBearing: Double? {
    let points = [
      "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
      "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW",
    ]

    guard let point = points.firstIndex(of: windDirection.uppercased()) else {
      return nil
    }

    return Double(point) * 22.5
  }

  var arrivalDelay: Duration? {
    guard let estimated = destination.estimated,
      let scheduled = destination.scheduled
    else { return nil }

    return .seconds(estimated.date.timeIntervalSince(scheduled.date))
  }
}

extension FlightInfo: Decodable {
  init(from decoder: Decoder) throws {
    let flifo = try Flifo(from: decoder)

    airlineCode = flifo.airlineCode ?? ""
    flightNumber = flifo.flightNumber ?? ""
    status = flifo.flightStatus ?? ""
    isFake = flifo.isFake ?? false

    aircraftModel = flifo.aircraftModel ?? ""
    equipmentCode = flifo.equipmentCode ?? ""
    noseNumber = flifo.noseNumber ?? ""
    tailNumber = flifo.tailNumber ?? ""

    origin = Endpoint(
      airportCode: flifo.originAirportCode ?? "",
      cityState: flifo.originCityState ?? "",
      summary: flifo.originText ?? "",
      terminal: flifo.departureTerminal ?? "",
      concourse: flifo.departureConcourse ?? "",
      gate: flifo.departureGate ?? "",
      scheduled: Instant(flifo.scheduledDepartureTimeLocal),
      estimated: Instant(flifo.estimatedDepartureTimeLocal),
      actual: Instant(flifo.actualDepartureTimeLocal))

    destination = Endpoint(
      airportCode: flifo.destinationAirportCode ?? "",
      cityState: flifo.destinationCityState ?? "",
      summary: flifo.destinationText ?? "",
      terminal: flifo.arrivalTerminal ?? "",
      concourse: flifo.arrivalConcourse ?? "",
      gate: flifo.arrivalGate ?? "",
      scheduled: Instant(flifo.scheduledArrivalTimeLocal),
      estimated: Instant(flifo.estimatedArrivalTimeLocal),
      actual: Instant(flifo.actualArrivalTimeLocal))

    flightDuration = minutes(flifo.flightDurationMinutes)
    timeRemaining = minutes(flifo.timeRemainingToDestination)

    airSpeed = measurement(flifo.airSpeedMPH, .milesPerHour)
    groundSpeed = measurement(flifo.groundSpeedMPH, .milesPerHour)
    altitude = measurement(flifo.altitudeFt, .feet)
    airTemperature = measurement(flifo.airTemperatureC, .celsius)
    windSpeed = measurement(flifo.windSpeedMPH, .milesPerHour)
    windDirection = flifo.windDirection ?? ""
  }
}

private struct Flifo: Decodable {
  let actualArrivalTimeLocal: String?
  let actualDepartureTimeLocal: String?
  let aircraftModel: String?
  let airSpeedMPH: String?
  let airTemperatureC: String?
  let airlineCode: String?
  let altitudeFt: String?
  let arrivalConcourse: String?
  let arrivalGate: String?
  let arrivalTerminal: String?
  let departureConcourse: String?
  let departureGate: String?
  let departureTerminal: String?
  let destinationAirportCode: String?
  let destinationCityState: String?
  let destinationText: String?
  let equipmentCode: String?
  let estimatedArrivalTimeLocal: String?
  let estimatedDepartureTimeLocal: String?
  let flightDurationMinutes: Int?
  let flightNumber: String?
  let flightStatus: String?
  let groundSpeedMPH: String?
  let isFake: Bool?
  let noseNumber: String?
  let originAirportCode: String?
  let originCityState: String?
  let originText: String?
  let scheduledArrivalTimeLocal: String?
  let scheduledDepartureTimeLocal: String?
  let tailNumber: String?
  let timeRemainingToDestination: Int?
  let windDirection: String?
  let windSpeedMPH: String?
}

extension FlightInfo.Instant {
  private static let iso8601 = [
    Date.ISO8601FormatStyle(includingFractionalSeconds: false),
    Date.ISO8601FormatStyle(includingFractionalSeconds: true),
  ]

  fileprivate init?(_ text: String?) {
    guard let text, !text.isEmpty,
      let date = Self.iso8601.lazy.compactMap({ try? $0.parse(text) }).first
    else { return nil }

    self.init(date: date, timeZone: TimeZone(iso8601Offset: text))
  }
}

extension TimeZone {
  // I hate that I need to do this manually but Foundation is useless here
  fileprivate init(iso8601Offset text: String) {
    let offset = text.suffix(6)
    let fields = offset.dropFirst().split(separator: ":")

    guard let sign = offset.first, sign == "+" || sign == "-",
      fields.count == 2, let hours = Int(fields[0]),
      let minutes = Int(fields[1])
    else {
      self = .gmt
      return
    }

    let seconds = (hours * 3600 + minutes * 60) * (sign == "-" ? -1 : 1)
    self = TimeZone(secondsFromGMT: seconds) ?? .gmt
  }
}

private func minutes(_ value: Int?) -> Duration? {
  guard let value else { return nil }
  return .seconds(value * 60)
}

private func measurement<UnitType: Dimension>(
  _ text: String?, _ unit: UnitType
) -> Measurement<UnitType>? {
  guard let text, let value = Double(text) else {
    return nil
  }

  return Measurement(value: value, unit: unit)
}

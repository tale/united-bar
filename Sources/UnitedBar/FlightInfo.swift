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

  let flightDuration: Duration
  let timeRemaining: Duration

  let airSpeed: Measurement<UnitSpeed>
  let groundSpeed: Measurement<UnitSpeed>
  let altitude: Measurement<UnitLength>
  let airTemperature: Measurement<UnitTemperature>
  let windSpeed: Measurement<UnitSpeed>
  let windDirection: String

  struct Endpoint {
    let airportCode: String
    let cityState: String
    let summary: String
    let terminal: String
    let concourse: String
    let gate: String
    let scheduled: Instant
    let estimated: Instant
    let actual: Instant?
  }

  struct Instant {
    let date: Date
    let timeZone: TimeZone
  }

  enum DecodeError: LocalizedError {
    case notANumber(String)
    case notADate(String)

    var errorDescription: String? {
      switch self {
      case .notANumber(let text): "Expected a number, got \"\(text)\""
      case .notADate(let text): "Expected an ISO 8601 stamp, got \"\(text)\""
      }
    }
  }
}

extension FlightInfo {
  var callSign: String { "\(airlineCode) \(flightNumber)" }

  var progress: Double {
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

  var arrivalDelay: Duration {
    .seconds(
      destination.estimated.date.timeIntervalSince(
        destination.scheduled.date))
  }
}

extension FlightInfo: Decodable {
  init(from decoder: Decoder) throws {
    let flifo = try Flifo(from: decoder)

    airlineCode = flifo.airlineCode
    flightNumber = flifo.flightNumber
    status = flifo.flightStatus
    isFake = flifo.isFake

    aircraftModel = flifo.aircraftModel
    equipmentCode = flifo.equipmentCode
    noseNumber = flifo.noseNumber
    tailNumber = flifo.tailNumber

    origin = try Endpoint(
      airportCode: flifo.originAirportCode,
      cityState: flifo.originCityState,
      summary: flifo.originText,
      terminal: flifo.departureTerminal,
      concourse: flifo.departureConcourse,
      gate: flifo.departureGate,
      scheduled: Instant(flifo.scheduledDepartureTimeLocal),
      estimated: Instant(flifo.estimatedDepartureTimeLocal),
      actual: Instant.parsed(flifo.actualDepartureTimeLocal))

    destination = try Endpoint(
      airportCode: flifo.destinationAirportCode,
      cityState: flifo.destinationCityState,
      summary: flifo.destinationText,
      terminal: flifo.arrivalTerminal,
      concourse: flifo.arrivalConcourse,
      gate: flifo.arrivalGate,
      scheduled: Instant(flifo.scheduledArrivalTimeLocal),
      estimated: Instant(flifo.estimatedArrivalTimeLocal),
      actual: Instant.parsed(flifo.actualArrivalTimeLocal))

    flightDuration = .seconds(flifo.flightDurationMinutes * 60)
    timeRemaining = .seconds(flifo.timeRemainingToDestination * 60)

    airSpeed = try measurement(flifo.airSpeedMPH, .milesPerHour)
    groundSpeed = try measurement(flifo.groundSpeedMPH, .milesPerHour)
    altitude = try measurement(flifo.altitudeFt, .feet)
    airTemperature = try measurement(flifo.airTemperatureC, .celsius)
    windSpeed = try measurement(flifo.windSpeedMPH, .milesPerHour)
    windDirection = flifo.windDirection
  }
}

private struct Flifo: Decodable {
  let actualArrivalTimeLocal: String?
  let actualDepartureTimeLocal: String?
  let aircraftModel: String
  let airSpeedMPH: String
  let airTemperatureC: String
  let airlineCode: String
  let altitudeFt: String
  let arrivalConcourse: String
  let arrivalGate: String
  let arrivalTerminal: String
  let departureConcourse: String
  let departureGate: String
  let departureTerminal: String
  let destinationAirportCode: String
  let destinationCityState: String
  let destinationText: String
  let equipmentCode: String
  let estimatedArrivalTimeLocal: String
  let estimatedDepartureTimeLocal: String
  let flightDurationMinutes: Int
  let flightNumber: String
  let flightStatus: String
  let groundSpeedMPH: String
  let isFake: Bool
  let noseNumber: String
  let originAirportCode: String
  let originCityState: String
  let originText: String
  let scheduledArrivalTimeLocal: String
  let scheduledDepartureTimeLocal: String
  let tailNumber: String
  let timeRemainingToDestination: Int
  let windDirection: String
  let windSpeedMPH: String
}

extension FlightInfo.Instant {
  private static let iso8601 = Date.ISO8601FormatStyle(
    includingFractionalSeconds: false)

  fileprivate init(_ text: String) throws {
    guard let date = try? Self.iso8601.parse(text) else {
      throw FlightInfo.DecodeError.notADate(text)
    }

    self.init(date: date, timeZone: TimeZone(iso8601Offset: text))
  }

  fileprivate static func parsed(_ text: String?) throws -> Self? {
    guard let text, !text.isEmpty else { return nil }
    return try Self(text)
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

private func measurement<UnitType: Dimension>(
  _ text: String, _ unit: UnitType
) throws -> Measurement<UnitType> {
  guard let value = Double(text) else {
    throw FlightInfo.DecodeError.notANumber(text)
  }

  return Measurement(value: value, unit: unit)
}

import Foundation

struct FlightInfo {
  let airlineCode: String
  let flightNumber: String
  let status: String
  let isFake: Bool
  let flightGuid: String
  let mapPath: String

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

  // United usually gives "<Phase> - <Description>" but sometimes it can be bad
  var statusPhase: String {
    guard let separator = status.range(of: " - ") else {
      let punctuality =
        /\s+(On Time|(\d+ Hours? )?(\d+ Minutes? )?(Early|Late))$/
      return status.replacing(punctuality, with: "")
    }

    return String(status[..<separator.lowerBound])
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

  // 15 minutes to determine we are landing is probably fine
  private static let landingWindow = Duration.seconds(15 * 60)
  var isLanding: Bool {
    guard destination.actual == nil, let timeRemaining else { return false }
    return timeRemaining > .zero && timeRemaining <= Self.landingWindow
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

    airlineCode = flifo.airlineCode ?? "UA"
    flightNumber = flifo.flightNumber ?? ""
    status = flifo.flightStatus ?? ""
    isFake = flifo.isFake ?? false
    flightGuid = flifo.flightGuid ?? ""
    mapPath = flifo.flightMapPath ?? ""

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

    flightDuration = flifo.flightDurationMinutes?.duration
    timeRemaining = flifo.timeRemainingToDestination?.duration

    airSpeed = measurement(flifo.airSpeedMPH, .milesPerHour)
    groundSpeed = measurement(flifo.groundSpeedMPH, .milesPerHour)
    altitude = measurement(flifo.altitudeFt, .feet)
    airTemperature = measurement(flifo.airTemperatureC, .celsius)
    windSpeed = measurement(flifo.windSpeedMPH, .milesPerHour)

    let bearing = flifo.windDirection ?? ""
    windDirection =
      bearing.caseInsensitiveCompare("NA") == .orderedSame ? "" : bearing
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
  let flightDurationMinutes: Minutes?
  let flightGuid: String?
  let flightMapPath: String?
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
  let timeRemainingToDestination: Minutes?
  let windDirection: String?
  let windSpeedMPH: String?
}

extension FlightInfo.Instant {
  private static let iso8601 = [
    Date.ISO8601FormatStyle(includingFractionalSeconds: false),
    Date.ISO8601FormatStyle(includingFractionalSeconds: true),
  ]

  private static let portal = Date.ParseStrategy(
    format: """
      \(day: .twoDigits) \(month: .abbreviated) \(year: .defaultDigits) \
      \(hour: .defaultDigits(clock: .twelveHour, hourCycle: .oneBased)):\
      \(minute: .twoDigits) \(dayPeriod: .standard(.abbreviated))
      """,
    locale: Locale(identifier: "en_US_POSIX"),
    timeZone: .gmt)

  fileprivate init?(_ text: String?) {
    guard let text, !text.isEmpty else { return nil }

    if let date = Self.iso8601.lazy.compactMap({ try? $0.parse(text) }).first {
      self.init(date: date, timeZone: TimeZone(iso8601Offset: text))
      return
    }

    guard let date = try? Self.portal.parse(text),
      date > Date(timeIntervalSince1970: 0)
    else { return nil }

    self.init(date: date, timeZone: .gmt)
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

private struct Minutes: Decodable {
  let duration: Duration?

  init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer()
    if let number = try? value.decode(Int.self) {
      duration = .seconds(number * 60)
      return
    }

    duration = (try? value.decode(String.self))
      .flatMap(Int.init)
      .map { .seconds($0 * 60) }
  }
}

private func measurement<UnitType: Dimension>(
  _ text: String?, _ unit: UnitType
) -> Measurement<UnitType>? {
  guard let text, let value = Double(text) else {
    return nil
  }

  return Measurement(value: value, unit: unit)
}

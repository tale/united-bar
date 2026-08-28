import OSLog

extension Logger {
  static let flight = Logger(subsystem: subsystem, category: "flight")
  static let manifest = Logger(subsystem: subsystem, category: "manifest")
  private static let subsystem = "me.tale.UnitedBar"
}

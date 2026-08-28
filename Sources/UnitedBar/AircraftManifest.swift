import Foundation
import OSLog

// You might be wondering what the hell this file does and I'll explain:
// We want the aircraft image and United makes it available, but it does it on
// the unitedwifi.com website using CSS selectors matching the equipment code of
// the aircraft.
//
// So we try and parse the CSS manifest and then fallback to a hard list.
actor AircraftManifest {
  static let shared = AircraftManifest()

  func url(equipmentCode: String) async -> URL? {
    let live = await parsed()

    if let file = live[equipmentCode] {
      return Self.imageBase.appending(path: file)
    }

    guard let file = Self.fallbackList[equipmentCode] else { return nil }

    Logger.manifest.notice(
      "\(equipmentCode, privacy: .public) not in stylesheet, falling back")

    return Self.imageBase.appending(path: file)
  }

  static func parse(stylesheet css: String) -> [String: String] {
    let code = /\.aircraft_([A-Za-z0-9]+)/
    let file = /exteriors\/([A-Za-z0-9_.-]+\.png)/
    var manifest: [String: String] = [:]

    for rule in css.split(separator: "}") {
      guard let brace = rule.firstIndex(of: "{"),
        let render = rule[brace...].firstMatch(of: file)
      else { continue }

      for selector in rule[..<brace].matches(of: code) {
        manifest[String(selector.1)] = String(render.1)
      }
    }

    return manifest
  }

  private var live: [String: String]?
  private func parsed() async -> [String: String] {
    if let live { return live }

    do {
      let (data, _) = try await URLSession.shared.data(from: Self.stylesheet)
      let manifest = Self.parse(
        stylesheet: String(decoding: data, as: UTF8.self))
      live = manifest

      Logger.manifest.info(
        """
        parsed \(manifest.count, privacy: .public) codes from stylesheet \
        (fallback table has \(Self.fallbackList.count, privacy: .public))
        """)

      return manifest
    } catch {
      Logger.manifest.error(
        """
        stylesheet unreachable, falling back to fallback table: \
        \(error.localizedDescription, privacy: .public)
        """)

      return [:]
    }
  }

  private static let stylesheet = URL(
    string: "https://www.unitedwifi.com/content/home/assets/css/v1/header.css")!
  private static let imageBase = URL(
    string: "https://www.unitedwifi.com/content/home/assets/img/v1/exteriors")!

  // Pulled as of August 28, 2026
  private static let fallbackList = [
    "19C": "A319_LF_a1.png",
    "19F": "A319_LF_a1.png",
    "19G": "A319_LF_a1.png",
    "19S": "A319_LF_a1.png",
    "20S": "A320_LF_a1.png",
    "21N": "A321neo.png",
    "37K": "737-9_LF_a1.png",
    "37R": "737-7_LF_a1.png",
    "37X": "737-MAX9_LF_a1.png",
    "47C": "744.png",
    "57Q": "757-200_LF_a1.png",
    "57X": "757-200_LF_a1.png",
    "67I": "767-300_LF_a1.png",
    "735": "735.png",
    "73A": "737-7_LF_a1.png",
    "73B": "737-9_LF_a1.png",
    "73C": "737-9_LF_a1.png",
    "73F": "737-8_LF_a1.png",
    "73G": "737-7_LF_a1.png",
    "73I": "737-9_LF_a1.png",
    "73J": "737-8_LF_a1.png",
    "73K": "737-8_LF_a1.png",
    "73L": "737-9_LF_a1.png",
    "73M": "737-8_LF_a1.png",
    "73P": "737-7_LF_a1.png",
    "73Q": "737-8_LF_a1.png",
    "73U": "737-8_LF_a1.png",
    "73V": "737-9_LF_a1.png",
    "73X": "737-8_LF_a1.png",
    "73Y": "737-8_LF_a1.png",
    "73Z": "737-7_LF_a1.png",
    "74C": "744.png",
    "75A": "757-300_LF_a1.png",
    "75B": "757-200_LF_a1.png",
    "75E": "757-300_LF_a1.png",
    "75J": "757-200_LF_a1.png",
    "75K": "757-200_LF_a1.png",
    "762": "762.png",
    "76A": "767-300_LF_a1.png",
    "76C": "767-300_LF_a1.png",
    "76E": "767-300_LF_a1.png",
    "76L": "767-300_LF_a1.png",
    "76N": "767-300_LF_a1.png",
    "76P": "767-400_LF_a1.png",
    "76S": "767-400_LF_a1.png",
    "77D": "777-200_LF_a1.png",
    "77E": "777-200_LF_a1.png",
    "77G": "777-200_LF_a1.png",
    "77H": "777-200_LF_a1.png",
    "77J": "777-200_LF_a1.png",
    "77Q": "777-200_LF_a1.png",
    "77X": "777-300_LF_a1.png",
    "77Y": "777-200_LF_a1.png",
    "787": "787.png",
    "78J": "787-10_LF_a1.png",
    "78V": "787-8_LF_a1.png",
    "78Z": "787-9_LF_a1.png",
    "ATR": "ATR.png",
    "BE1": "BE1.png",
    "C2C": "CRJ.png",
    "C7A": "CR7.png",
    "C7G": "CR7.png",
    "CR7": "CR7.png",
    "CRJ": "CRJ.png",
    "DH2": "DH2.png",
    "DH3": "DH3.png",
    "DH4": "DH4.png",
    "DH8": "DH8.png",
    "E70": "E70.png",
    "E75": "E75.png",
    "E7A": "E75.png",
    "EM2": "EM2.png",
    "ER4": "ER4.png",
    "ERJ": "ERJ.png",
    "Q200": "Q200.png",
    "SF3": "SF3.png",
  ]
}

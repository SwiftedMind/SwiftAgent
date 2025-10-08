// By Dennis Müller

import Foundation

private func jsonString(
  from value: some Encodable,
  pretty: Bool = false,
) throws -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
  if pretty { encoder.outputFormatting.insert(.prettyPrinted) }
  encoder.dateEncodingStrategy = .iso8601

  let data = try encoder.encode(value)
  return String(decoding: data, as: UTF8.self)
}

package extension Encodable {
  func jsonString(pretty: Bool = false) throws -> String {
    try Internal.jsonString(from: self, pretty: pretty)
  }
}

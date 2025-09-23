// By Dennis Müller

import Foundation
import FoundationModels
import OpenAI

extension JSONSchema {
	/// Convenience: build a `JSONSchema` from *any* `Encodable` payload by round‑tripping
	/// through `Data` (no intermediate `String` allocation).
	static func fromEncodable<E: Encodable>(
		_ value: E,
		encoder: JSONEncoder? = nil,
		decoder: JSONDecoder? = nil
	) throws -> JSONSchema {
		let encoder = encoder ?? _makeSchemaEncoder()
		let decoder = decoder ?? _makeSchemaDecoder()
		let data = try encoder.encode(value)
		return try decoder.decode(JSONSchema.self, from: data)
	}
}

/// FoundationModels glue
extension GenerationSchema {
	/// Convert a `GenerationSchema` (from FoundationModels) into your local `JSONSchema`.
	func asJSONSchema(
		encoder: JSONEncoder? = nil,
		decoder: JSONDecoder? = nil
	) throws -> JSONSchema {
		let encoder = encoder ?? _makeSchemaEncoder()
		let decoder = decoder ?? _makeSchemaDecoder()
		let data = try encoder.encode(self)
		return try decoder.decode(JSONSchema.self, from: data)
	}
}

@inline(__always)
private func _makeSchemaEncoder() -> JSONEncoder {
	let encoder = JSONEncoder()
	// Keep options stable; sorting helps with deterministic output when needed.
	encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
	encoder.dateEncodingStrategy = .iso8601
	return encoder
}

@inline(__always)
private func _makeSchemaDecoder() -> JSONDecoder {
	let decoder = JSONDecoder()
	// No special date handling required for JSON Schema keywords,
	// but keep this uniform in case upstream adds dates to metadata.
	decoder.dateDecodingStrategy = .iso8601
	return decoder
}

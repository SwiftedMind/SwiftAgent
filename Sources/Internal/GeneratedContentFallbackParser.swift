// By Dennis Müller

import Foundation
import FoundationModels

package enum GeneratedContentFallbackParser {
	/// Converts arbitrary generated content into a flat dictionary of string values.
	///
	/// This helper allows callers to surface recoverable tool payloads even when
	/// strongly typed decoding fails.
	package static func values(from generatedContent: GeneratedContent) -> [String: String] {
		guard
			let jsonData = generatedContent.jsonString.data(using: .utf8),
			let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) else {
			return ["value": generatedContent.jsonString]
		}

		return values(fromJSONObject: jsonObject)
	}

	private static func values(fromJSONObject jsonObject: Any) -> [String: String] {
		if let dictionary = jsonObject as? [String: Any] {
			var parsedDictionary: [String: String] = [:]

			for (key, value) in dictionary {
				parsedDictionary[key] = stringRepresentation(for: value)
			}

			return parsedDictionary
		}

		if let array = jsonObject as? [Any] {
			return ["values": stringRepresentation(for: array)]
		}

		return ["value": stringRepresentation(for: jsonObject)]
	}

	private static func stringRepresentation(for value: Any) -> String {
		if let stringValue = value as? String {
			return stringValue
		}

		if let boolValue = value as? Bool {
			return boolValue ? "true" : "false"
		}

		if let numberValue = value as? NSNumber {
			return numberValue.stringValue
		}

		if
			let dictionaryValue = value as? [String: Any],
			let jsonStringValue = serializedJSONString(fromJSONObject: dictionaryValue) {
			return jsonStringValue
		}

		if
			let arrayValue = value as? [Any],
			let jsonStringValue = serializedJSONString(fromJSONObject: arrayValue) {
			return jsonStringValue
		}

		return String(describing: value)
	}

	private static func serializedJSONString(fromJSONObject jsonObject: Any) -> String? {
		guard
			JSONSerialization.isValidJSONObject(jsonObject),
			let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys]) else {
			return nil
		}

		return String(data: jsonData, encoding: .utf8)
	}
}

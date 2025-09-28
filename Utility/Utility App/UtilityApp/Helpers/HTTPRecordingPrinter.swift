// By Dennis Müller

import Foundation
import SwiftAgent

struct HTTPRecordingPrinter: Sendable {
	struct RequestContext: Sendable {
		var sequenceNumber: Int
		var method: HTTPMethod
		var url: URL
		var headers: [String: String]
		var bodyDescription: String?
	}

	struct ResponseContext: Sendable {
		var sequenceNumber: Int
		var statusCode: Int
		var bodyDescription: String?
	}

	private let divider = String(repeating: "-", count: 72)
	private let sensitiveHeaderFields: Set<String> = ["Authorization"]

	func printRequest(_ context: RequestContext) {
		let requestTitle = "⟪ Request #\(context.sequenceNumber) ⟫ \(context.method.rawValue) \(context.url.path)"
		print(sectionHeader(requestTitle))
		print("Headers:")
		if context.headers.isEmpty {
			print("  (none)")
		} else {
			for (field, value) in context.headers.sorted(by: { $0.key < $1.key }) {
				let maskedValue = maskIfSensitive(field: field, value: value)
				print("  \(field): \(maskedValue)")
			}
		}
		if let bodyDescription = context.bodyDescription, bodyDescription.isEmpty == false {
			print("Body:")
			print(bodyDescription)
		} else {
			print("Body: (empty)")
		}
		print(divider)
	}

	func printResponse(_ context: ResponseContext) {
		let responseTitle = "⟪ Response #\(context.sequenceNumber) ⟫ HTTP \(context.statusCode)"
		print(sectionHeader(responseTitle))
		if let bodyDescription = context.bodyDescription, bodyDescription.isEmpty == false {
			print(bodyDescription)
		} else {
			print("(no body)")
		}
		print(divider)
	}

	func printStream(sequenceNumber: Int, statusCode: Int?, rawEventPayload: String, note: String? = nil) {
		var titleComponents = ["⟪ Stream #\(sequenceNumber) ⟫"]
		if let statusCode {
			titleComponents.append("HTTP \(statusCode)")
		}
		if let note, note.isEmpty == false {
			titleComponents.append("[\(note)]")
		}
		let streamTitle = titleComponents.joined(separator: " ")
		print(sectionHeader(streamTitle))
		print("Copy the payload below into a recorded response string:")
		print(wrapInRawString(rawEventPayload))
		print(divider)
	}

	func makeJSONStringBlock(from data: Data?) -> String? {
		guard let data else { return nil }

		if let prettyPrinted = try? prettyPrintedJSONString(from: data) {
			return wrapInRawString(prettyPrinted)
		}
		if let string = String(data: data, encoding: .utf8), string.isEmpty == false {
			return wrapInRawString(string)
		}
		return nil
	}

	func wrapInRawString(_ string: String) -> String {
		"#\"\"\"\n\(string)\n\"\"\"#"
	}

	private func prettyPrintedJSONString(from data: Data) throws -> String {
		let object = try JSONSerialization.jsonObject(with: data, options: [])
		let formattedData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
		return String(decoding: formattedData, as: UTF8.self)
	}

	private func maskIfSensitive(field: String, value: String) -> String {
		guard sensitiveHeaderFields.contains(field) else { return value }

		if value.lowercased().hasPrefix("bearer ") {
			return "Bearer <redacted>"
		}
		return "<redacted>"
	}

	private func sectionHeader(_ title: String) -> String {
		let paddingLength = max(0, (divider.count - title.count) / 2)
		let padding = String(repeating: "-", count: paddingLength)
		return "\(padding) \(title) \(padding)"
	}
}

// By Dennis Müller

import Foundation
import FoundationModels

public struct Transcript: Sendable, Equatable {
	public var entries: [Entry]

	public init(entries: [Entry] = []) {
		self.entries = entries
	}

	package mutating func upsert(_ entry: Entry) {
		if let existingIndex = entries.firstIndex(where: { $0.id == entry.id }) {
			entries[existingIndex] = entry
		} else {
			entries.append(entry)
		}
	}

	public func resolved<Provider: LanguageModelProvider>(
		in session: Provider,
	) -> Provider.ResolvedTranscript {
		Transcript.Resolved(transcript: self, session: session)
	}

	public func streaming<Provider: LanguageModelProvider>(
		in session: Provider,
	) -> Provider.StreamingTranscript {
		Transcript.Streaming(transcript: self, session: session)
	}
}

// MARK: - RandomAccessCollection Conformance

extension Transcript: RandomAccessCollection, RangeReplaceableCollection {
	public var startIndex: Int { entries.startIndex }
	public var endIndex: Int { entries.endIndex }

	public subscript(position: Int) -> Entry {
		entries[position]
	}

	public func index(after i: Int) -> Int {
		entries.index(after: i)
	}

	public func index(before i: Int) -> Int {
		entries.index(before: i)
	}

	public init() {
		entries = []
	}

	public mutating func replaceSubrange(_ subrange: Range<Int>, with newElements: some Collection<Entry>) {
		entries.replaceSubrange(subrange, with: newElements)
	}
}

public extension SwiftAgent.Transcript {
	enum Entry: Sendable, Identifiable, Equatable {
		case prompt(Prompt)
		case reasoning(Reasoning)
		case toolCalls(ToolCalls)
		case toolOutput(ToolOutput)
		case response(Response)

		public var id: String {
			switch self {
			case let .prompt(prompt):
				prompt.id
			case let .reasoning(reasoning):
				reasoning.id
			case let .toolCalls(toolCalls):
				toolCalls.id
			case let .toolOutput(toolOutput):
				toolOutput.id
			case let .response(response):
				response.id
			}
		}
	}

	struct Prompt: Sendable, Identifiable, Equatable {
		public var id: String
		public var input: String
		public var sources: Data
		package var prompt: String

		package init(
			id: String = UUID().uuidString,
			input: String,
			sources: Data,
			prompt: String,
		) {
			self.id = id
			self.input = input
			self.sources = sources
			self.prompt = prompt
		}
	}

	struct Reasoning: Sendable, Identifiable, Equatable {
		public var id: String
		public var summary: [String]
		public var encryptedReasoning: String?
		public var status: Status?

		package init(
			id: String,
			summary: [String],
			encryptedReasoning: String?,
			status: Status? = nil,
		) {
			self.id = id
			self.summary = summary
			self.encryptedReasoning = encryptedReasoning
			self.status = status
		}
	}

	enum Status: Sendable, Identifiable, Equatable {
		case completed
		case incomplete
		case inProgress

		public var id: Self { self }
	}

	struct ToolCalls: Sendable, Identifiable, Equatable {
		public var id: String
		public var calls: [ToolCall]

		public init(id: String = UUID().uuidString, calls: [ToolCall]) {
			self.id = id
			self.calls = calls
		}
	}
}

// MARK: - ToolCalls RandomAccessCollection Conformance

extension Transcript.ToolCalls: RandomAccessCollection, RangeReplaceableCollection {
	public var startIndex: Int { calls.startIndex }
	public var endIndex: Int { calls.endIndex }

	public subscript(position: Int) -> Transcript.ToolCall {
		calls[position]
	}

	public func index(after i: Int) -> Int {
		calls.index(after: i)
	}

	public func index(before i: Int) -> Int {
		calls.index(before: i)
	}

	public init() {
		id = UUID().uuidString
		calls = []
	}

	public mutating func replaceSubrange(
		_ subrange: Range<Int>,
		with newElements: some Collection<Transcript.ToolCall>,
	) {
		calls.replaceSubrange(subrange, with: newElements)
	}
}

public extension Transcript {
	struct ToolCall: Sendable, Identifiable, Equatable {
		public var id: String
		public var callId: String
		public var toolName: String
		public var arguments: GeneratedContent
		public var status: Status?

		package init(
			id: String,
			callId: String,
			toolName: String,
			arguments: GeneratedContent,
			status: Status?,
		) {
			self.id = id
			self.callId = callId
			self.toolName = toolName
			self.arguments = arguments
			self.status = status
		}
	}

	struct ToolOutput: Sendable, Identifiable, Equatable {
		public var id: String
		public var callId: String
		public var toolName: String
		public var segment: Segment
		public var status: Status?

		public init(
			id: String,
			callId: String,
			toolName: String,
			segment: Segment,
			status: Status?,
		) {
			self.id = id
			self.callId = callId
			self.toolName = toolName
			self.segment = segment
			self.status = status
		}
	}

	struct Response: Sendable, Identifiable, Equatable {
		public var id: String
		public var segments: [Segment]
		public var status: Status

		public init(
			id: String,
			segments: [Segment],
			status: Status,
		) {
			self.id = id
			self.segments = segments
			self.status = status
		}

		public var text: String? {
			var components: [String] = []
			for segment in segments {
				switch segment {
				case let .text(textSegment):
					components.append(textSegment.content)
				case .structure:
					return nil
				}
			}

			guard !components.isEmpty else { return nil }

			return components.joined(separator: "\n")
		}
	}

	enum Segment: Sendable, Identifiable, Equatable {
		case text(TextSegment)
		case structure(StructuredSegment)

		public var id: String {
			switch self {
			case let .text(textSegment):
				textSegment.id
			case let .structure(structuredSegment):
				structuredSegment.id
			}
		}
	}

	struct TextSegment: Sendable, Identifiable, Equatable {
		public var id: String
		public var content: String

		public init(id: String = UUID().uuidString, content: String) {
			self.id = id
			self.content = content
		}
	}

	struct StructuredSegment: Sendable, Identifiable, Equatable {
		public var id: String
		public var typeName: String
		public var content: GeneratedContent

		public init(id: String = UUID().uuidString, typeName: String = "", content: GeneratedContent) {
			self.id = id
			self.typeName = typeName
			self.content = content
		}

		public init(id: String = UUID().uuidString, typeName: String = "", content: some ConvertibleToGeneratedContent) {
			self.id = id
			self.typeName = typeName
			self.content = content.generatedContent
		}
	}
}

// MARK: - Pretty Printing

public extension Transcript {
	func prettyPrintedDescription(indentedBy indentationLevel: Int = 0) -> String {
		prettyPrintedLines(indentedBy: indentationLevel).joined(separator: "\n")
	}
}

extension Transcript: CustomStringConvertible, CustomDebugStringConvertible {
	public var description: String {
		prettyPrintedDescription()
	}

	public var debugDescription: String {
		prettyPrintedDescription()
	}
}

private extension Transcript {
	func prettyPrintedLines(indentedBy indentationLevel: Int) -> [String] {
		var lines: [String] = []
		let currentIndentation = transcriptIndentation(for: indentationLevel)
		lines.append("\(currentIndentation)Transcript [")
		if entries.isEmpty {
			let childIndentation = transcriptIndentation(for: indentationLevel + 1)
			lines.append("\(childIndentation)<empty>")
		} else {
			for entry in entries {
				lines.append(contentsOf: entry.prettyPrintedLines(indentedBy: indentationLevel + 1))
			}
		}
		lines.append("\(currentIndentation)]")
		return lines
	}
}

private extension Transcript.Entry {
	func prettyPrintedLines(indentedBy indentationLevel: Int) -> [String] {
		switch self {
		case let .prompt(prompt):
			prompt.prettyPrintedLines(indentedBy: indentationLevel, headline: "Prompt")
		case let .reasoning(reasoning):
			reasoning.prettyPrintedLines(indentedBy: indentationLevel)
		case let .toolCalls(toolCalls):
			toolCalls.prettyPrintedLines(indentedBy: indentationLevel)
		case let .toolOutput(toolOutput):
			toolOutput.prettyPrintedLines(indentedBy: indentationLevel)
		case let .response(response):
			response.prettyPrintedLines(indentedBy: indentationLevel)
		}
	}
}

private extension Transcript.Prompt {
	func prettyPrintedLines(indentedBy indentationLevel: Int, headline: String) -> [String] {
		var lines: [String] = []
		let currentIndentation = transcriptIndentation(for: indentationLevel)
		lines.append("\(currentIndentation)\(headline)(id: \(id)) {")
		lines.append(contentsOf: transcriptPrettyField(name: "input", value: input, indentationLevel: indentationLevel + 1))
		lines.append(contentsOf: transcriptPrettyField(
			name: "prompt",
			value: prompt,
			indentationLevel: indentationLevel + 1,
		))
		lines.append("\(currentIndentation)}")
		return lines
	}
}

private extension Transcript.Reasoning {
	func prettyPrintedLines(indentedBy indentationLevel: Int) -> [String] {
		var lines: [String] = []
		let currentIndentation = transcriptIndentation(for: indentationLevel)
		lines.append("\(currentIndentation)Reasoning(id: \(id)) {")
		lines.append(contentsOf: transcriptPrettyStringCollection(
			name: "summary",
			values: summary,
			indentationLevel: indentationLevel + 1,
		))
		lines.append(contentsOf: transcriptPrettyOptionalField(
			name: "encryptedReasoning",
			value: encryptedReasoning,
			indentationLevel: indentationLevel + 1,
		))
		lines.append(contentsOf: transcriptPrettyOptionalField(
			name: "status",
			value: status.map { String(describing: $0) },
			indentationLevel: indentationLevel + 1,
		))
		lines.append("\(currentIndentation)}")
		return lines
	}
}

private extension Transcript.ToolCalls {
	func prettyPrintedLines(indentedBy indentationLevel: Int) -> [String] {
		var lines: [String] = []
		let currentIndentation = transcriptIndentation(for: indentationLevel)
		lines.append("\(currentIndentation)ToolCalls(id: \(id)) {")
		lines.append(contentsOf: transcriptPrettyCollection(
			name: "calls",
			indentationLevel: indentationLevel + 1,
			elements: calls,
			renderElement: { call, elementIndentationLevel in
				call.prettyPrintedLines(indentedBy: elementIndentationLevel)
			},
		))
		lines.append("\(currentIndentation)}")
		return lines
	}
}

private extension Transcript.ToolCall {
	func prettyPrintedLines(indentedBy indentationLevel: Int) -> [String] {
		var lines: [String] = []
		let currentIndentation = transcriptIndentation(for: indentationLevel)
		lines.append("\(currentIndentation)ToolCall(id: \(id)) {")
		lines.append(contentsOf: transcriptPrettyField(
			name: "callId",
			value: callId,
			indentationLevel: indentationLevel + 1,
		))
		lines.append(contentsOf: transcriptPrettyField(
			name: "toolName",
			value: toolName,
			indentationLevel: indentationLevel + 1,
		))
		lines.append(contentsOf: transcriptPrettyValue(
			value: transcriptPrettyJSONString(from: arguments),
			indentationLevel: indentationLevel + 1,
			name: "arguments",
		))
		lines.append(contentsOf: transcriptPrettyOptionalField(
			name: "status",
			value: status.map { String(describing: $0) },
			indentationLevel: indentationLevel + 1,
		))
		lines.append("\(currentIndentation)}")
		return lines
	}
}

private extension Transcript.ToolOutput {
	func prettyPrintedLines(indentedBy indentationLevel: Int) -> [String] {
		var lines: [String] = []
		let currentIndentation = transcriptIndentation(for: indentationLevel)
		lines.append("\(currentIndentation)ToolOutput(id: \(id)) {")
		lines.append(contentsOf: transcriptPrettyField(
			name: "callId",
			value: callId,
			indentationLevel: indentationLevel + 1,
		))
		lines.append(contentsOf: transcriptPrettyField(
			name: "toolName",
			value: toolName,
			indentationLevel: indentationLevel + 1,
		))
		lines.append(contentsOf: transcriptPrettyOptionalField(
			name: "status",
			value: status.map { String(describing: $0) },
			indentationLevel: indentationLevel + 1,
		))
		lines.append(contentsOf: transcriptPrettyCollection(
			name: "segment",
			indentationLevel: indentationLevel + 1,
			elements: [segment],
			renderElement: { segment, elementIndentationLevel in
				segment.prettyPrintedLines(indentedBy: elementIndentationLevel)
			},
		))
		lines.append("\(currentIndentation)}")
		return lines
	}
}

private extension Transcript.Response {
	func prettyPrintedLines(indentedBy indentationLevel: Int) -> [String] {
		var lines: [String] = []
		let currentIndentation = transcriptIndentation(for: indentationLevel)
		lines.append("\(currentIndentation)Response(id: \(id)) {")
		lines.append(contentsOf: transcriptPrettyField(
			name: "status",
			value: String(describing: status),
			indentationLevel: indentationLevel + 1,
		))
		lines.append(contentsOf: transcriptPrettyCollection(
			name: "segments",
			indentationLevel: indentationLevel + 1,
			elements: segments,
			renderElement: { segment, elementIndentationLevel in
				segment.prettyPrintedLines(indentedBy: elementIndentationLevel)
			},
		))
		lines.append("\(currentIndentation)}")
		return lines
	}
}

private extension Transcript.Segment {
	func prettyPrintedLines(indentedBy indentationLevel: Int) -> [String] {
		switch self {
		case let .text(textSegment):
			textSegment.prettyPrintedLines(indentedBy: indentationLevel)
		case let .structure(structuredSegment):
			structuredSegment.prettyPrintedLines(indentedBy: indentationLevel)
		}
	}
}

private extension Transcript.TextSegment {
	func prettyPrintedLines(indentedBy indentationLevel: Int) -> [String] {
		var lines: [String] = []
		let currentIndentation = transcriptIndentation(for: indentationLevel)
		lines.append("\(currentIndentation)TextSegment(id: \(id)) {")
		lines.append(contentsOf: transcriptPrettyField(
			name: "content",
			value: content,
			indentationLevel: indentationLevel + 1,
		))
		lines.append("\(currentIndentation)}")
		return lines
	}
}

private extension Transcript.StructuredSegment {
	func prettyPrintedLines(indentedBy indentationLevel: Int) -> [String] {
		var lines: [String] = []
		let currentIndentation = transcriptIndentation(for: indentationLevel)
		lines.append("\(currentIndentation)StructuredSegment(id: \(id)) {")
		lines.append(contentsOf: transcriptPrettyValue(
			value: transcriptPrettyJSONString(from: content),
			indentationLevel: indentationLevel + 1,
			name: "content",
		))
		lines.append("\(currentIndentation)}")
		return lines
	}
}

// MARK: - Pretty Printing Helpers

private func transcriptIndentation(for indentationLevel: Int) -> String {
	String(repeating: "  ", count: indentationLevel)
}

private func transcriptPrettyField(name: String, value: String, indentationLevel: Int) -> [String] {
	transcriptPrettyValue(value: value, indentationLevel: indentationLevel, name: name)
}

private func transcriptPrettyOptionalField(name: String, value: String?, indentationLevel: Int) -> [String] {
	guard let value else { return [] }

	return transcriptPrettyField(name: name, value: value, indentationLevel: indentationLevel)
}

private func transcriptPrettyStringCollection(
	name: String,
	values: [String],
	indentationLevel: Int,
) -> [String] {
	let indentation = transcriptIndentation(for: indentationLevel)
	guard !values.isEmpty else {
		return ["\(indentation)\(name): []"]
	}

	var lines = ["\(indentation)\(name): ["]
	for value in values {
		lines.append(contentsOf: transcriptPrettyValue(
			value: value,
			indentationLevel: indentationLevel + 1,
			bullet: "- ",
		))
	}
	lines.append("\(indentation)]")
	return lines
}

private func transcriptPrettyCollection<Element>(
	name: String,
	indentationLevel: Int,
	elements: [Element],
	renderElement: (Element, Int) -> [String],
) -> [String] {
	let indentation = transcriptIndentation(for: indentationLevel)
	guard !elements.isEmpty else {
		return ["\(indentation)\(name): []"]
	}

	var lines = ["\(indentation)\(name): ["]
	for element in elements {
		lines.append(contentsOf: renderElement(element, indentationLevel + 1))
	}
	lines.append("\(indentation)]")
	return lines
}

private func transcriptPrettyValue(
	value: String,
	indentationLevel: Int,
	name: String? = nil,
	bullet: String? = nil,
) -> [String] {
	let indentation = transcriptIndentation(for: indentationLevel)
	let rawLines = value.components(separatedBy: "\n")
	let valueLines: [String] = if rawLines.count == 1, rawLines.first?.isEmpty == true {
		["<empty>"]
	} else {
		rawLines
	}

	if let name {
		guard let firstLine = valueLines.first else {
			return ["\(indentation)\(name):"]
		}

		if valueLines.count == 1 {
			return ["\(indentation)\(name): \(firstLine)"]
		}
		var lines = ["\(indentation)\(name):"]
		let nestedIndentation = transcriptIndentation(for: indentationLevel + 1)
		for line in valueLines {
			lines.append("\(nestedIndentation)\(line)")
		}
		return lines
	}

	if let bullet {
		var lines: [String] = []
		let bulletIndentation = transcriptIndentation(for: indentationLevel)
		for (index, line) in valueLines.enumerated() {
			if index == 0 {
				lines.append("\(bulletIndentation)\(bullet)\(line)")
			} else {
				let nestedIndentation = transcriptIndentation(for: indentationLevel + 1)
				lines.append("\(nestedIndentation)\(line)")
			}
		}
		return lines
	}

	return valueLines.map { "\(indentation)\($0)" }
}

private func transcriptPrettyJSONString(from generatedContent: GeneratedContent) -> String {
	let rawJSONString = generatedContent.jsonString
	guard let data = rawJSONString.data(using: .utf8) else {
		return rawJSONString
	}
	guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
		return rawJSONString
	}
	guard JSONSerialization.isValidJSONObject(jsonObject) else {
		return rawJSONString
	}
	guard let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys, .prettyPrinted])
	else {
		return rawJSONString
	}

	return String(decoding: prettyData, as: UTF8.self)
}

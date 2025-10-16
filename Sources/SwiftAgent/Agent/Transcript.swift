// By Dennis Müller

import Foundation
import FoundationModels

/// A conversation transcript built by the agent.
///
/// The transcript is an ordered log of prompts, tool activity, and model
/// responses produced during a session. Use it to inspect streaming progress,
/// pretty‑print for debugging, or decode provider‑specific structured output.
public struct Transcript: Sendable, Equatable {
  /// The ordered entries that make up the transcript. New entries are appended
  /// at the end as the session progresses.
  public var entries: [Entry]

  /// Creates a transcript, optionally seeded with existing entries.
  public init(entries: [Entry] = []) {
    self.entries = entries
  }

  /// Inserts the entry if it does not exist, or replaces the existing entry
  /// with the same `id`. Order is preserved when appending.
  package mutating func upsert(_ entry: Entry) {
    if let existingIndex = entries.firstIndex(where: { $0.id == entry.id }) {
      entries[existingIndex] = entry
    } else {
      entries.append(entry)
    }
  }

  /// Decodes this transcript using the session's decoder into the provider's
  /// `DecodedTranscript` representation.
  ///
  /// - Parameters:
  ///   - session: The session to use to decode the transcript.
  /// - Returns: The decoded transcript.
  public func decoded<SessionSchema: LanguageModelSessionSchema>(
    using schema: SessionSchema,
  ) throws -> SessionSchema.DecodedTranscript {
    let decoder = TranscriptDecoder(for: schema)
    return try decoder.decode(self)
  }

  /// Returns the structured output and status from the most recent response
  /// when the session is configured for structured‑only output.
  ///
  /// - Returns: `nil` while streaming is in progress or when no response is
  ///   available.
  /// - Throws: A `GenerationError` if unexpected text or multiple structured
  ///   segments are present.
  package func structuredOutputFromLastResponse() throws -> LastResponseStructuredOutput? {
    guard let response = entries
      .reversed()
      .first(where: {
        if case .response = $0 { return true }
        return false
      })
      .flatMap({ entry -> Response? in
        if case let .response(response) = entry {
          return response
        }
        return nil
      }) else {
      return nil
    }

    // Response is still empty, so data might still be streaming in
    if response.segments.isEmpty {
      return nil
    }

    // Text is forbidden in structured-only mode
    if !response.textSegments.isEmpty {
      throw GenerationError.unexpectedTextResponse(.init())
    }

    // We only ever support one structured segment
    let structuredSegments = response.structuredSegments
    if structuredSegments.count != 1 {
      throw GenerationError.unexpectedStructuredResponse(.init())
    }

    return LastResponseStructuredOutput(
      status: response.status,
      segment: structuredSegments[0],
    )
  }
}

package extension Transcript {
  /// Convenience bundle containing the last response status and its single
  /// structured segment.
  struct LastResponseStructuredOutput: Sendable, Equatable {
    /// The completion status of the last response.
    var status: Transcript.Status
    /// The single structured segment produced by the last response.
    let segment: Transcript.StructuredSegment
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
  /// A single unit in a transcript. Entries are identified by a stable `id`
  /// to support updates during streaming.
  enum Entry: Sendable, Identifiable, Equatable {
    /// The final rendered prompt that was sent to the model.
    case prompt(Prompt)
    /// A summarized reasoning trace, if provided by the model.
    case reasoning(Reasoning)
    /// One or more tool invocations emitted by the model.
    case toolCalls(ToolCalls)
    /// Output emitted by a tool in response to a prior tool call.
    case toolOutput(ToolOutput)
    /// The model's response for the turn.
    case response(Response)

    /// Stable identifier for this entry.
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

  /// The final rendered prompt that was sent to the model, alongside the
  /// original input and prompt sources used to construct it.
  struct Prompt: Sendable, Identifiable, Equatable {
    /// Identifier for this prompt instance.
    public var id: String
    /// The user's raw input used to build the prompt.
    public var input: String
    /// Opaque data describing prompt sources used to reproduce the prompt.
    public var sources: Data
    /// The full rendered prompt string sent to the model.
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

  /// A lightweight summary of the model's private reasoning, when available.
  struct Reasoning: Sendable, Identifiable, Equatable {
    /// Identifier for this reasoning instance.
    public var id: String
    /// High‑level reasoning summary lines.
    public var summary: [String]
    /// Provider‑specific encrypted reasoning payload, if present.
    public var encryptedReasoning: String?
    /// The status of the reasoning step, if reported.
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

  /// The lifecycle state of a response or step.
  enum Status: Sendable, Identifiable, Equatable {
    /// The operation finished successfully.
    case completed
    /// The operation ended before completion.
    case incomplete
    /// The operation is still in progress.
    case inProgress

    /// Identifiable conformance uses the case value itself.
    public var id: Self { self }
  }

  /// A collection of tool calls emitted in a single turn.
  struct ToolCalls: Sendable, Identifiable, Equatable {
    /// Identifier for this group of tool calls.
    public var id: String
    /// The ordered tool calls.
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
  /// A single tool invocation requested by the model.
  struct ToolCall: Sendable, Identifiable, Equatable {
    /// Identifier for this tool call record.
    public var id: String
    /// Correlation identifier supplied by the model.
    public var callId: String
    /// The tool's canonical name.
    public var toolName: String
    /// JSON arguments for the tool call.
    public var arguments: GeneratedContent
    /// Optional status of the tool call as it progresses.
    public var status: Status?

    public init(
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

  /// Output produced by a tool in response to a call.
  struct ToolOutput: Sendable, Identifiable, Equatable {
    /// Identifier for this tool output record.
    public var id: String
    /// Correlation identifier matching the originating tool call.
    public var callId: String
    /// The tool's canonical name.
    public var toolName: String
    /// The tool output as a segment (text or structured).
    public var segment: Segment
    /// Optional status reflecting the processing state.
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

  /// The model's response for a single turn.
  struct Response: Sendable, Identifiable, Equatable {
    /// Identifier for this response.
    public var id: String
    /// Ordered response segments (text and/or structured).
    public var segments: [Segment]
    /// Whether the response completed or is still in progress.
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

    /// All text segments in order.
    public var textSegments: [TextSegment] {
      segments.compactMap { segment in
        switch segment {
        case let .text(textSegment):
          textSegment
        case .structure:
          nil
        }
      }
    }

    /// All structured segments in order.
    public var structuredSegments: [StructuredSegment] {
      segments.compactMap { segment in
        switch segment {
        case let .structure(structuredSegment):
          structuredSegment
        case .text:
          nil
        }
      }
    }

    /// Convenience joined text from all text segments, or `nil` when none.
    public var text: String? {
      let contents = textSegments.map(\.content)
      if contents.isEmpty { return nil }
      return contents.joined(separator: "\n")
    }
  }

  /// A response or tool output segment.
  enum Segment: Sendable, Identifiable, Equatable {
    /// A unit of plain text.
    case text(TextSegment)
    /// A unit of structured content.
    case structure(StructuredSegment)

    /// Stable identifier for the underlying segment.
    public var id: String {
      switch self {
      case let .text(textSegment):
        textSegment.id
      case let .structure(structuredSegment):
        structuredSegment.id
      }
    }
  }

  /// A unit of plain text produced by the model or a tool.
  struct TextSegment: Sendable, Identifiable, Equatable {
    /// Identifier for this segment.
    public var id: String
    /// The textual content.
    public var content: String

    public init(id: String = UUID().uuidString, content: String) {
      self.id = id
      self.content = content
    }
  }

  /// A unit of structured content produced by the model or a tool.
  struct StructuredSegment: Sendable, Identifiable, Equatable {
    /// Identifier for this segment.
    public var id: String
    /// Optional type hint for the structured payload.
    public var typeName: String
    /// The structured payload as generated content.
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

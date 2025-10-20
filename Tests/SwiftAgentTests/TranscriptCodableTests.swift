// By Dennis Müller

import Foundation
import struct FoundationModels.GeneratedContent
@testable import SwiftAgent
import Testing

@Suite("Transcript Codable")
struct TranscriptCodableTests {
  @Test("Transcript round-trips through Codable while preserving GeneratedContent fields")
  func transcriptRoundTrip() throws {
    // Exercise the custom Codable path by including several GeneratedContent payloads.
    let toolCallArguments = try GeneratedContent(json: #"{ "location": "New York City" }"#)
    let structuredSegmentContent = try GeneratedContent(json: #"{ "forecast": "Sunny", "temperature": 23 }"#)

    // Build a transcript that touches prompts, tool calls, tool output, and response segments.
    let prompt = Transcript.Prompt(
      id: "prompt-id",
      input: "What is the weather today?",
      sources: Data([0x01, 0x02]),
      prompt: "Weather prompt",
    )

    let toolCall = Transcript.ToolCall(
      id: "tool-call-id",
      callId: "call-identifier",
      toolName: "WeatherTool",
      arguments: toolCallArguments,
      status: .completed,
    )

    let structuredSegment = Transcript.StructuredSegment(
      id: "segment-id",
      typeName: "weather",
      content: structuredSegmentContent,
    )

    let toolOutput = Transcript.ToolOutput(
      id: "tool-output-id",
      callId: "call-identifier",
      toolName: "WeatherTool",
      segment: .structure(structuredSegment),
      status: .completed,
    )

    let response = Transcript.Response(
      id: "response-id",
      segments: [
        .text(.init(id: "text-segment", content: "It is sunny.")),
        .structure(structuredSegment),
      ],
      status: .completed,
    )

    let transcript = Transcript(entries: [
      .prompt(prompt),
      .toolCalls(.init(id: "tool-calls-id", calls: [toolCall])),
      .toolOutput(toolOutput),
      .response(response),
    ])

    // Round-trip through Codable and ensure the GeneratedContent JSON payloads survive unchanged.
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let encodedData = try encoder.encode(transcript)

    let decoder = JSONDecoder()
    let decodedTranscript = try decoder.decode(Transcript.self, from: encodedData)

    #expect(decodedTranscript.entries.count == transcript.entries.count)

    guard case let .toolCalls(decodedToolCallsEntry) = decodedTranscript.entries[1],
          case let .toolCalls(originalToolCallsEntry) = transcript.entries[1]
    else {
      Issue.record("Expected second transcript entry to be .toolCalls in both transcripts")
      return
    }

    let decodedToolCall = try #require(decodedToolCallsEntry.calls.first)
    let originalToolCall = try #require(originalToolCallsEntry.calls.first)
    #expect(decodedToolCall.arguments.stableJsonString == originalToolCall.arguments.stableJsonString)

    guard case let .toolOutput(decodedToolOutputEntry) = decodedTranscript.entries[2],
          case let .toolOutput(originalToolOutputEntry) = transcript.entries[2]
    else {
      Issue.record("Expected third transcript entry to be .toolOutput in both transcripts")
      return
    }
    guard case let .structure(decodedToolOutputSegment) = decodedToolOutputEntry.segment,
          case let .structure(originalToolOutputSegment) = originalToolOutputEntry.segment
    else {
      Issue.record("Expected tool output segment to be structured in both transcripts")
      return
    }

    #expect(decodedToolOutputSegment.typeName == originalToolOutputSegment.typeName)
    #expect(decodedToolOutputSegment.content.stableJsonString == originalToolOutputSegment.content.stableJsonString)

    guard case let .response(decodedResponseEntry) = decodedTranscript.entries[3],
          case let .response(originalResponseEntry) = transcript.entries[3]
    else {
      Issue.record("Expected fourth transcript entry to be .response in both transcripts")
      return
    }
    guard decodedResponseEntry.segments.count == originalResponseEntry.segments.count else {
      Issue.record("Response segment counts differ after round-trip encoding")
      return
    }
    guard case let .structure(decodedResponseSegment) = decodedResponseEntry.segments[1],
          case let .structure(originalResponseSegment) = originalResponseEntry.segments[1]
    else {
      Issue.record("Expected second response segment to be structured in both transcripts")
      return
    }

    #expect(decodedResponseSegment.typeName == originalResponseSegment.typeName)
    #expect(decodedResponseSegment.content.stableJsonString == originalResponseSegment.content.stableJsonString)
  }
}

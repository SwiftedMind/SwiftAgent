// By Dennis Müller

import Foundation
import struct FoundationModels.GeneratedContent
import OpenAISession

// MARK: - OpenAISession.DecodedTranscript Mock Extensions

extension Transcript.Decoded<OpenAISession> {
  /// An empty transcript for testing empty states
  static let mockEmpty = OpenAISession.DecodedTranscript()

  /// A conversation with multiple tool runs
  static let mock = OpenAISession.DecodedTranscript(entries: [
    .prompt(.mock),
    .reasoning(.mock),
    .toolRun(.calculator(.mockFinal)),
    .toolRun(.weather(.mockFinal)),
    .response(.mock),
    .prompt(.mock),
    .response(.mock),
  ])

  /// A conversation with in-progress tool runs
  static let mockPartial = OpenAISession.DecodedTranscript(entries: [
    .prompt(.mock),
    .toolRun(.calculator(.mockPartial)),
  ])
}

// MARK: - OpenAISession.DecodedTranscript.Entry Mock Extensions

extension Transcript.Decoded<OpenAISession>.Entry {
  static let mockPrompt = OpenAISession.DecodedTranscript.Entry.prompt(.mock)
  static let mockReasoning = OpenAISession.DecodedTranscript.Entry.reasoning(.mock)
  static let mockToolRun = OpenAISession.DecodedTranscript.Entry.toolRun(.calculator(.mockFinal))
  static let mockResponse = OpenAISession.DecodedTranscript.Entry.response(.mock)
}

// // MARK: - OpenAISession.DecodedTranscript.Prompt Mock Extensions

extension Transcript.Decoded<OpenAISession>.Prompt {
  /// A prompt with grounding sources
  static let mock = OpenAISession.DecodedTranscript.Prompt(
    id: "prompt-002",
    input: "What's the weather like today?",
    sources: [.currentDate(Date())],
    prompt: "Context: Current date is 2024-01-15\n\nWhat's the weather like today?",
    error: nil,
  )
}

// MARK: - OpenAISession.DecodedTranscript.Reasoning Mock Extensions

extension Transcript.Decoded<OpenAISession>.Reasoning {
  static let mock = OpenAISession.DecodedTranscript.Reasoning(
    id: "reasoning-001",
    summary: [
      "User is asking for a mathematical calculation",
      "I should use the calculator tool to compute 15 + 27",
      "The result will be 42",
    ],
  )
}

// MARK: - OpenAISession.DecodedTranscript.Response Mock Extensions

extension Transcript.Decoded<OpenAISession>.Response {
  /// A simple text response
  static let mock = OpenAISession.DecodedTranscript.Response(
    id: "response-001",
    segments: [
      .text(.mockTextSegment),
    ],
    status: .completed,
  )

  /// A response with multiple text segments
  static let mockMultiSegment = OpenAISession.DecodedTranscript.Response(
    id: "response-002",
    segments: [
      .text(.mockTextSegment),
      .text(.mockLongTextSegment),
    ],
    status: .completed,
  )

  /// A structured response with weather report
  static let mockStructured = OpenAISession.DecodedTranscript.Response(
    id: "response-003",
    segments: [
      .structure(.mockWeatherReport),
    ],
    status: .completed,
  )
}

// MARK: - OpenAISession.DecodedTranscript.Segment Mock Extensions

extension Transcript.Decoded<OpenAISession>.Segment {
  static let mockTextSegment = OpenAISession.DecodedTranscript.Segment.text(.mockTextSegment)
  static let mockStructuredSegment = OpenAISession.DecodedTranscript.Segment.structure(.mockWeatherReport)
}

// MARK: - OpenAISession.DecodedTranscript.TextSegment Mock Extensions

extension Transcript.Decoded<OpenAISession>.TextSegment {
  static let mockTextSegment = OpenAISession.DecodedTranscript.TextSegment(
    id: "text-001",
    content: "The result is 42.",
  )

  static let mockLongTextSegment = OpenAISession.DecodedTranscript.TextSegment(
    id: "text-002",
    content: "This is a longer response that demonstrates how the UI handles multi-line text content. It includes several sentences to show text wrapping and formatting in the SwiftUI views.",
  )
}

// MARK: - OpenAISession.DecodedTranscript.StructuredSegment Mock Extensions

extension Transcript.Decoded<OpenAISession>.StructuredSegment {
  static let mockWeatherReport = OpenAISession.DecodedTranscript.StructuredSegment(
    id: "structured-001",
    typeName: "weatherReport",
    content: .weatherReport(.mockFinal),
  )
}

extension ToolRun<CalculatorTool> {
  static let mockFinal = ToolRun<CalculatorTool>(
    id: "calc-001",
    arguments: .final(CalculatorTool.Arguments.mock),
    output: CalculatorTool.Output.mock,
    problem: nil,
    rawArguments: GeneratedContent(kind: .null),
    rawOutput: GeneratedContent(kind: .null),
  )

  static let mockPartial = ToolRun<CalculatorTool>(
    id: "calc-002",
    arguments: .partial(CalculatorTool.Arguments.PartiallyGenerated.mock0),
    output: nil,
    problem: nil,
    rawArguments: GeneratedContent(kind: .null),
    rawOutput: nil,
  )

  static let mockFailed = ToolRun<CalculatorTool>(
    id: "calc-003",
    output: nil,
    problem: nil,
    error: TranscriptDecodingError.ToolRunResolution.mock,
    rawArguments: GeneratedContent(kind: .null),
    rawOutput: nil,
  )
}

extension ToolRun<WeatherTool> {
  static let mockFinal = ToolRun<WeatherTool>(
    id: "weather-001",
    arguments: .final(WeatherTool.Arguments.mock),
    output: WeatherTool.Output.mock,
    problem: nil,
    rawArguments: GeneratedContent(kind: .null),
    rawOutput: GeneratedContent(kind: .null),
  )

  static let mockPartial = ToolRun<WeatherTool>(
    id: "weather-002",
    arguments: .partial(WeatherTool.Arguments.PartiallyGenerated.mock),
    output: nil,
    problem: nil,
    rawArguments: GeneratedContent(kind: .null),
    rawOutput: nil,
  )

  static let mockFailed = ToolRun<WeatherTool>(
    id: "weather-003",
    output: nil,
    problem: nil,
    error: TranscriptDecodingError.ToolRunResolution.mock,
    rawArguments: GeneratedContent(kind: .null),
    rawOutput: nil,
  )
}

// MARK: - CalculatorTool.Arguments Mock Extensions

extension CalculatorTool.Arguments {
  static let mock = CalculatorTool.Arguments(
    firstNumber: 15.0,
    operation: "+",
    secondNumber: 27.0,
  )
}

extension CalculatorTool.Arguments.PartiallyGenerated {
  static let mock0 = try! CalculatorTool.Arguments.PartiallyGenerated(
    try! GeneratedContent(json: """
    {
    }
    """),
  )

  static let mock1 = try! CalculatorTool.Arguments.PartiallyGenerated(
    try! GeneratedContent(json: """
    {
      "firstNumber": 15.0
    }
    """),
  )

  static let mock2 = try! CalculatorTool.Arguments.PartiallyGenerated(
    try! GeneratedContent(json: """
    {
      "firstNumber": 15.0,
      "operation": "+"
    }
    """),
  )

  static let mock3 = try! CalculatorTool.Arguments.PartiallyGenerated(
    try! GeneratedContent(json: """
    {
      "firstNumber": 15.0,
      "operation": "+",
      "secondNumber": 32.0
    }
    """),
  )
}

extension CalculatorTool.Output {
  static let mock = CalculatorTool.Output(
    result: 42.0,
  )
}

// MARK: - WeatherTool.Arguments Mock Extensions

extension WeatherTool.Arguments {
  static let mock = WeatherTool.Arguments(
    location: "San Francisco",
  )
}

extension WeatherTool.Arguments.PartiallyGenerated {
  static let mock = try! WeatherTool.Arguments.PartiallyGenerated(
    try! GeneratedContent(json: """
    {
      "location": "San Fra"
    }
    """),
  )
}

extension WeatherTool.Output {
  static let mock = WeatherTool.Output(
    location: "San Francisco",
    temperature: 18,
    condition: "Partly Cloudy",
    humidity: 72,
  )
}

// MARK: - StructuredOutputUpdate Mock Extensions

extension StructuredOutputUpdate<WeatherReport> {
  static let mockFinal = StructuredOutputUpdate<WeatherReport>(
    id: "weather-report-001",
    content: .final(WeatherReport.Schema.mock),
    rawContent: GeneratedContent(kind: .null),
  )

  static let mockPartial = StructuredOutputUpdate<WeatherReport>(
    id: "weather-report-002",
    content: .partial(WeatherReport.Schema.PartiallyGenerated.mock),
    rawContent: GeneratedContent(kind: .null),
  )

  static let mockFailed = StructuredOutputUpdate<WeatherReport>(
    id: "weather-report-003",
    error: GeneratedContent.mockUnknown,
    rawContent: GeneratedContent(kind: .null),
  )
}

// MARK: - WeatherReport.Schema Mock Extensions

extension WeatherReport.Schema {
  static let mock = WeatherReport.Schema(
    temperature: 18.5,
    condition: "Partly Cloudy",
    humidity: 72,
  )
}

extension WeatherReport.Schema.PartiallyGenerated {
  static let mock = try! WeatherReport.Schema.PartiallyGenerated(
    try! GeneratedContent(json: """
    {
      "temperature": 18.5,
      "condition": "Partly Cloudy"
    }
    """),
  )
}

// MARK: - GeneratedContent Mock Extensions

extension GeneratedContent {
  static let mockUnknown = try! GeneratedContent(json: """
  {
    "wrongTemperature": 18.5,
  }
  """)
}

// MARK: - Transcript.ToolCall Mock Extensions

extension Transcript.ToolCall {
  static let mockUnknown = Transcript.ToolCall(
    id: "unknown-001",
    callId: "call-unknown-001",
    toolName: "unknown_tool",
    arguments: GeneratedContent(kind: .null),
    status: .completed,
  )
}

// MARK: - Transcript.StructuredSegment Mock Extensions

extension Transcript.StructuredSegment {
  static let mockUnknown = Transcript.StructuredSegment(
    id: "unknown-structured-001",
    typeName: "unknownType",
    content: GeneratedContent(kind: .null),
  )
}

// MARK: - TranscriptDecodingError Mock Extensions

extension TranscriptDecodingError.ToolRunResolution {
  static let mock = TranscriptDecodingError.ToolRunResolution.unknownTool(name: "nonexistent_tool")
}

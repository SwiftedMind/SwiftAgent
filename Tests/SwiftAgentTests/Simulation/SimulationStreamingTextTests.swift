// By Dennis Müller

import Foundation
import FoundationModels
@testable import SimulatedSession
@testable import SwiftAgent
import Testing

@SessionSchema
private struct SessionSchema {}

@Suite("Simulation - Streaming - Text")
struct SimulationStreamingTextTests {
  typealias Transcript = SwiftAgent.Transcript

  // MARK: - Properties

  private let session: SimulatedSession<SessionSchema>

  // MARK: - Initialization

  init() async {
    let configuration = SimulationAdapter.Configuration(defaultGenerations: [.textResponse("Hello, World!")])
    session = SimulatedSession(
      schema: SessionSchema(),
      instructions: "",
      configuration: configuration,
    )
  }

  @Test("Single streaming response")
  func singleStreamingResponse() async throws {
    let (generatedTranscript, latestContent) = try await processStreamResponse()
    try validateTranscript(generatedTranscript: generatedTranscript)
    #expect(latestContent == "Hello, World!")
  }

  // MARK: - Private Test Helper Methods

  private func processStreamResponse() async throws -> (Transcript, String?) {
    let stream = try session.streamResponse(
      to: "prompt",
      using: .default,
      options: .init(),
    )

    var generatedTranscript = Transcript()
    var latestContent: String?

    for try await snapshot in stream {
      generatedTranscript = snapshot.transcript
      if let content = snapshot.content {
        latestContent = content
      }
    }

    return (generatedTranscript, latestContent)
  }

  private func validateTranscript(generatedTranscript: Transcript) throws {
    #expect(generatedTranscript.count == 2)

    guard case let .prompt(prompt) = generatedTranscript[0] else {
      Issue.record("First transcript entry is not .prompt")
      return
    }

    #expect(prompt.input == "prompt")

    guard case let .response(response) = generatedTranscript[1] else {
      Issue.record("Second transcript entry is not .response")
      return
    }

    #expect(response.segments.count == 1)
    guard case let .text(textSegment) = response.segments.first else {
      Issue.record("Second transcript entry is not .text")
      return
    }

    #expect(textSegment.content == "Hello, World!")
  }
}

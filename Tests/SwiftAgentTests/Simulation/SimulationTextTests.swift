// By Dennis Müller

import Foundation
import FoundationModels
@testable import SimulatedSession
@testable import SwiftAgent
import Testing

@SessionSchema
private struct SessionSchema {}

@Suite("Simulation - Text")
struct SimulationTextTests {
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

  @Test("Single response")
  func singleResponse() async throws {
    let (generatedTranscript, content) = try await processStreamResponse()
    try validateTranscript(generatedTranscript: generatedTranscript)
    #expect(content == "Hello, World!")
  }

  // MARK: - Private Test Helper Methods

  private func processStreamResponse() async throws -> (Transcript, String?) {
    let response = try await session.respond(to: "prompt", options: .init())
    return (response.transcript, response.content)
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

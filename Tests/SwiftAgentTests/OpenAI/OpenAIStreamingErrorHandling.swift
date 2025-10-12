// By Dennis Müller

import Dependencies
import Foundation
import FoundationModels
import OpenAI
@testable import OpenAISession
@testable import SwiftAgent
import Testing

@LanguageModelProvider(.openAI)
private final class ExampleSession {}

@Suite("OpenAI - Streaming - Error Handling")
struct OpenAIStreamingErrorTests {
  typealias Transcript = SwiftAgent.Transcript

  @Test("'CancellationError' is thrown")
  func cancellationError() async throws {
    let mockHTTPClient = ReplayHTTPClient<CreateModelResponseQuery>(
      recordedResponse: .init(body: "", statusCode: 200, delay: .milliseconds(10)),
    )
    let configuration = OpenAIConfiguration(httpClient: mockHTTPClient)
    let session = ExampleSession(instructions: "", configuration: configuration)

    do {
      let task = Task {
        let stream = try session.streamResponse(
          to: "prompt",
          using: .gpt5,
          options: .init(include: [.reasoning_encryptedContent]),
        )
        for try await _ in stream {
          Issue.record("Expected the stream to finish because of the cancellation")
        }

        // When a task is cancelled, the stream should finish
        #expect(Task.isCancelled)
      }
      task.cancel()
      try await task.value
    } catch {
      Issue.record("Expected CancellationError but received \(error)")
    }
  }

  @Test("Error event surfaces a failure")
  func errorEventSurfacesFailure() async throws {
    let mockHTTPClient = ReplayHTTPClient<CreateModelResponseQuery>(
      recordedResponse: .init(body: insufficientQuotaErrorResponse, statusCode: 200),
    )
    let configuration = OpenAIConfiguration(httpClient: mockHTTPClient)
    let session = ExampleSession(instructions: "", configuration: configuration)

    let stream = try session.streamResponse(
      to: "prompt",
      using: .gpt5,
      options: .init(include: [.reasoning_encryptedContent]),
    )

    do {
      for try await _ in stream {}
      Issue.record("Expected streamResponse to throw when an error event is received")
      return
    } catch {
      guard let generationError = error as? GenerationError else {
        Issue.record("Expected GenerationError but received \(error)")
        return
      }

      switch generationError {
      case let .providerError(context):
        #expect(context.code == "insufficient_quota")
      default:
        Issue.record("Unexpected error thrown: \(generationError)")
      }
    }
  }

  @Test("'invalid_api_key' is thrown even when streaming")
  func invalidAPIKeyError() async throws {
    let mockHTTPClient = ReplayHTTPClient<CreateModelResponseQuery>(
      recordedResponse: .init(body: missingAPIKeyErrorResponse, statusCode: 401),
    )
    let configuration = OpenAIConfiguration(httpClient: mockHTTPClient)
    let session = ExampleSession(instructions: "", configuration: configuration)

    do {
      let stream = try session.streamResponse(
        to: "prompt",
        using: .gpt5,
        options: .init(include: [.reasoning_encryptedContent]),
      )
      for try await _ in stream {
        Issue.record("Expected streamResponse to throw when an error event is received")
        return
      }
    } catch {
      guard let generationError = error as? GenerationError else {
        Issue.record("Expected GenerationError but received \(error)")
        return
      }

      switch generationError {
      case let .providerError(context):
        #expect(context.code == "invalid_api_key")
      default:
        Issue.record("Unexpected error thrown: \(generationError)")
      }
    }
  }
}

// MARK: - Mock Responses

private let insufficientQuotaErrorResponse: String = #"""
event: response.created
data: {"type":"response.created","sequence_number":0,"response":{"id":"resp_0265b28bea036ff60068df845920648196938b4f36acdcee37","object":"response","created_at":1759478873,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"medium","summary":null},"safety_identifier":null,"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: response.in_progress
data: {"type":"response.in_progress","sequence_number":1,"response":{"id":"resp_0265b28bea036ff60068df845920648196938b4f36acdcee37","object":"response","created_at":1759478873,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"medium","summary":null},"safety_identifier":null,"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: error
data: {"type":"error","sequence_number":2,"error":{"type":"insufficient_quota","code":"insufficient_quota","message":"You exceeded your current quota, please check your plan and billing details. For more information on this error, read the docs: https://platform.openai.com/docs/guides/error-codes/api-errors.","param":null}}

event: response.failed
data: {"type":"response.failed","sequence_number":3,"response":{"id":"resp_0265b28bea036ff60068df845920648196938b4f36acdcee37","object":"response","created_at":1759478873,"status":"failed","background":false,"error":{"code":"insufficient_quota","message":"You exceeded your current quota, please check your plan and billing details. For more information on this error, read the docs: https://platform.openai.com/docs/guides/error-codes/api-errors."},"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"medium","summary":null},"safety_identifier":null,"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}
"""#

private let missingAPIKeyErrorResponse: String = #"""
{
  "error": {
    "message": "Incorrect API key provided: ''. You can find your API key at https://platform.openai.com/account/api-keys.",
    "type": "invalid_request_error",
    "param": null,
    "code": "invalid_api_key"
  }
}
"""#

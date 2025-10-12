// By Dennis Müller

import Dependencies
import Foundation
import FoundationModels
import OpenAI
@testable import OpenAISession
@testable import SwiftAgent
import Testing

/*

 TODO: More unit tests.
 TODO: Update the Session init to have a "tools" parameter when no @Tool properties are defined.
 TODO: Go through the API flow and check if this is now somewhat final
      -> Do this by finally building the example app properly
 TODO: Start writing new documentation
 TODO: Changelog
 */

@LanguageModelProvider(.openAI)
private final class ExampleSession {
  @StructuredOutput(WeatherForecast.self) var weatherForecast
}

@Suite("OpenAIAdapter - Structured Output")
struct OpenAIAdapterStructuredOutputTests {
  typealias Transcript = SwiftAgent.Transcript

  // MARK: - Properties

  private let session: ExampleSession
  private let mockHTTPClient: ReplayHTTPClient<CreateModelResponseQuery>

  // MARK: - Initialization

  init() async {
    mockHTTPClient = ReplayHTTPClient<CreateModelResponseQuery>(
      recordedResponse: .init(body: structuredOutputResponse),
    )
    let configuration = OpenAIConfiguration(httpClient: mockHTTPClient)
    session = ExampleSession(instructions: "", configuration: configuration)
  }

  @Test("Structured response is decoded into WeatherForecast")
  func structuredResponseIsDecoded() async throws {
    let agentResponse = try await performStructuredResponse()

    try await validateHTTPRequests()
    validateAgentResponse(agentResponse)
    await validateSessionTranscript()
  }

  // MARK: - Private Test Helper Methods

  private func performStructuredResponse() async throws -> ExampleSession.Response<WeatherForecast.Schema> {
    try await session.weatherForecast.generate(
      from: "Provide the latest weather update.",
      using: .gpt5_mini,
      options: .init(include: [.reasoning_encryptedContent]),
    )
  }

  private func validateAgentResponse(
    _ agentResponse: ExampleSession.Response<WeatherForecast.Schema>,
  ) {
    #expect(agentResponse.content.temperatureCelsius == 22)
    #expect(agentResponse.content.condition == "Partly Cloudy")
    #expect(agentResponse.tokenUsage?.totalTokens == 97)

    let generatedTranscript = agentResponse.transcript
    #expect(generatedTranscript.count == 3)

    guard case let .prompt(promptEntry) = generatedTranscript[0] else {
      Issue.record("Expected first transcript entry to be .prompt")
      return
    }

    #expect(promptEntry.input == "Provide the latest weather update.")

    guard case let .reasoning(reasoningEntry) = generatedTranscript[1] else {
      Issue.record("Expected second transcript entry to be .reasoning")
      return
    }

    #expect(reasoningEntry.id == "rs_0358c95ad546f0d80168e806a57ea0819f90750abfe2bc8f1d")
    #expect(reasoningEntry.summary == [])

    guard case let .response(responseEntry) = generatedTranscript[2] else {
      Issue.record("Expected third transcript entry to be .response")
      return
    }

    #expect(responseEntry.segments.count == 1)
    guard case let .structure(structuredSegment) = responseEntry.segments.first else {
      Issue.record("Expected response segment to be .structure")
      return
    }

    #expect(structuredSegment.typeName == ExampleSession.DecodableWeatherForecast.name)

    do {
      let decodedForecast = try WeatherForecast.Schema(structuredSegment.content)
      #expect(decodedForecast.temperatureCelsius == agentResponse.content.temperatureCelsius)
      #expect(decodedForecast.condition == agentResponse.content.condition)
    } catch {
      Issue.record("Failed to decode structured segment: \(error)")
    }
  }

  private func validateHTTPRequests() async throws {
    let recordedRequests = await mockHTTPClient.recordedRequests()

    let request = try #require(recordedRequests.first)
    guard case let .inputItemList(items) = request.body.input else {
      Issue.record("Recorded request body input is not .inputItemList")
      return
    }

    #expect(items.count == 1)

    guard case let .inputMessage(message) = items[0] else {
      Issue.record("Recorded request item is not .inputMessage")
      return
    }
    guard case let .textInput(text) = message.content else {
      Issue.record("Expected message content to be text input")
      return
    }

    #expect(text == "Provide the latest weather update.")

    let expectedOutputConfig = CreateModelResponseQuery.TextResponseConfigurationOptions.OutputFormat
      .StructuredOutputsConfig(
        name: WeatherForecast.name,
        schema: .dynamicJsonSchema(WeatherForecast.Schema.generationSchema),
        description: nil,
        strict: false,
      )

    guard request.body.text == .jsonSchema(expectedOutputConfig) else {
      Issue.record("Expected text configuration format to be present")
      return
    }
  }

  @MainActor
  private func validateSessionTranscript() {
    #expect(session.transcript.count == 3)
  }
}

@Generable
struct WeatherForecast: StructuredOutput {
  static let name: String = "weather_forecast"

  @Generable
  struct Schema {
    var temperatureCelsius: Double
    var condition: String
  }
}

// MARK: - Mock Responses

private let structuredOutputResponse: String = #"""
{
  "id": "resp_0358c95ad546f0d80168e806a49f7c819f8c20d9127a317a5b",
  "object": "response",
  "created_at": 1760036516,
  "status": "completed",
  "background": false,
  "billing": {
    "payer": "openai"
  },
  "error": null,
  "incomplete_details": null,
  "instructions": null,
  "max_output_tokens": null,
  "max_tool_calls": null,
  "model": "gpt-5-mini-2025-08-07",
  "output": [
    {
      "id": "rs_0358c95ad546f0d80168e806a57ea0819f90750abfe2bc8f1d",
      "type": "reasoning",
      "encrypted_content": "gAAAAABo6AamFlhVFGvEXk9DUNGgFJj-72aPMKiWUNhiQgP978RUdA5i0iaD81049doUUO8iRWwVOhwcq_6tRGNfw_ljWNT0DJxsZnC_XH2bmhKU_djV6zBSEnCP-osV3TqcqNAlOC9Qo6eFsmecGJ0C_FwnEbLp8wycZ2TJis-NKfDFoZfk2E4zd6aa5NNPo_Znuy7FMmkP6YvosdOlgfdATg9_BSFMgM5Kprg3UK_cQcALNbF4xNjZmA_-ohFFdRb6vyak449XlatrTOJF9mQcoOv5mjlOX_ozLs3vz7GKO2w18hAz0C6_EUvXZ7ZsQQtKo8VpCcdF72rpaQSaUbel3DT0txEI7j121Bwb-DpGCMIxQqHAH22bOLqAoBds4TXkNCYYl4bYfgidVwMl3Tr-I5n7lO-LGcwTnm-CqZ9L12uOXpnfmsgiByKgoEyiOGyZKJV9veTXRnqEvKN3rS7VcWy2GHHDJuOeyFzYjqp8QwQjPse6f2SfilmmiWf3Ebe0neu9cb_djO1pFwi2pf02qTo_dRBMLR6Il6qITDLR90zu2wNy6an4xnoidc1v2QdqrKgUcXldOFZ0KRBSBmhEncoEO6KxGtYMHkM-VUxKdjTP1BJO00FsjtudsTU1H8sNK2ErVH_1pMEWrQE1cM-L03YyQuTQ1Dg6hNJV0Vy0MNsBzsifpoAyDs0s568EouecQ-yDkzLSzAIGVn3YwzY5-olN5iDFWQkxMxzBsKVjTZnpgru5YZ1qb4UaXsSZdQkGKYG3uoviETZlywtYe5fuf2pDfdpko2RukB8qHsO2abQYzqhY-_j4hApC6MdA6IF7qpMK2i0DtVvAOjM0EOnGrB17uiHDv-dqbcGu8U2tucbD4_2C_pjePQqvYB2SGoBs6FMdU3hcF8Ocgt4D4F4pCndnQq8d3g==",
      "summary": []
    },
    {
      "id": "msg_0358c95ad546f0d80168e806a5cddc819fa55f702cfa2502ad",
      "type": "message",
      "status": "completed",
      "content": [
        {
          "type": "output_text",
          "annotations": [],
          "logprobs": [],
          "text": "{\"temperatureCelsius\":22,\"condition\":\"Partly Cloudy\"}"
        }
      ],
      "role": "assistant"
    }
  ],
  "parallel_tool_calls": true,
  "previous_response_id": null,
  "prompt_cache_key": null,
  "reasoning": {
    "effort": "minimal",
    "summary": "detailed"
  },
  "safety_identifier": null,
  "service_tier": "default",
  "store": false,
  "temperature": 1,
  "text": {
    "format": {
      "type": "json_schema",
      "description": null,
      "name": "weatherForecast",
      "schema": {
        "type": "object",
        "properties": {
          "temperatureCelsius": {
            "type": "number",
            "description": "Forecast temperature in degrees Celsius."
          },
          "condition": {
            "type": "string",
            "description": "Short weather condition description (e.g., Sunny, Rainy, Cloudy)."
          }
        },
        "required": [
          "temperatureCelsius",
          "condition"
        ],
        "additionalProperties": false
      },
      "strict": true
    },
    "verbosity": "low"
  },
  "tool_choice": "auto",
  "tools": [],
  "top_logprobs": 0,
  "top_p": 1,
  "truncation": "disabled",
  "usage": {
    "input_tokens": 72,
    "input_tokens_details": {
      "cached_tokens": 0
    },
    "output_tokens": 25,
    "output_tokens_details": {
      "reasoning_tokens": 0
    },
    "total_tokens": 97
  },
  "user": null,
  "metadata": {}
}
"""#

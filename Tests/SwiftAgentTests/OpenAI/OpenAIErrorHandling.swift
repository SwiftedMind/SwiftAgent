//
//  ExampleSession.swift
//  SwiftAgent
//
//  Created by Dennis Müller on 03.10.25.
//


// By Dennis Müller

import Dependencies
import Foundation
import FoundationModels
import OpenAI
@testable import OpenAISession
@testable import SwiftAgent
import Testing

@LanguageModelProvider(for: .openAI)
private final class ExampleSession {}

// TODO: Doesn't succeed because replay mock client can't yet return custom status codes, so it returns 200 + an error schema which fails to decode
// TODO: Add unit tests for a variety of error cases and in both streaming and non-streaming variants

@Suite("OpenAIAdapter - Error Handling")
struct OpenAIErrorHandling {
	typealias Transcript = SwiftAgent.Transcript

	// MARK: - Properties

	private let session: ExampleSession
	private let mockHTTPClient: ReplayHTTPClient<CreateModelResponseQuery>

	// MARK: - Initialization

	init() async {
		mockHTTPClient = ReplayHTTPClient<CreateModelResponseQuery>(recordedResponse: insufficientQuotaErrorResponse)
		let configuration = OpenAIConfiguration(httpClient: mockHTTPClient)
		session = ExampleSession(instructions: "", configuration: configuration)
	}

	@Test("'insufficient_quote' is thrown error")
	func errorEventSurfacesFailure() async throws {

		do {
			_ = try await session.respond(
				to: "prompt",
				using: .gpt5,
				options: .init(include: [.reasoning_encryptedContent]),
			)
			Issue.record("Expected respond to throw")
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
}

// MARK: - Mock Responses

private let insufficientQuotaErrorResponse: String = #"""
{
	"error": {
		"message": "You exceeded your current quota, please check your plan and billing details. For more information on this error, read the docs: https://platform.openai.com/docs/guides/error-codes/api-errors.",
		"type": "insufficient_quota",
		"param": null,
		"code": "insufficient_quota"
	}
}
"""#

// By Dennis Müller

import Foundation
import FoundationModels
import OpenAI
@testable import OpenAISession
@testable import SwiftAgent

struct RecordingScenario: Identifiable {
	typealias Execution = @MainActor @Sendable (_ adapter: OpenAIAdapter) async throws -> Void

	var id: UUID = .init()
	var title: String
	var details: String
	var instructions: String
	var tools: [any SwiftAgentTool]
	var execute: Execution

	init(
		title: String,
		details: String,
		instructions: String,
		tools: [any SwiftAgentTool],
		execute: @escaping Execution,
	) {
		self.title = title
		self.details = details
		self.instructions = instructions
		self.tools = tools
		self.execute = execute
	}
}

extension RecordingScenario {
	static var sampleScenarios: [RecordingScenario] {
		[streamingWeatherScenario]
	}

	private static var streamingWeatherScenario: RecordingScenario {
		RecordingScenario(
			title: "Streaming Weather Update",
			details: "Streams reasoning and assistant text for a weather request.",
			instructions: "You are a helpful assistant that reports weather updates.",
			tools: [WeatherTool()],
			execute: { adapter in
				typealias WeatherTranscript = SwiftAgent.Transcript<NoContext>
				let userPrompt = "What is the weather in New York City, USA?"
				let prompt = WeatherTranscript.Prompt(input: userPrompt, prompt: userPrompt)
				let initialTranscript = WeatherTranscript(entries: [.prompt(prompt)])

				let stream = adapter.streamResponse(
					to: prompt,
					generating: String.self,
					including: initialTranscript,
					options: .init(include: [.reasoning_encryptedContent]),
				)

				var generatedTranscript = WeatherTranscript()
				for try await update in stream {
					if case let .transcript(entry) = update {
						generatedTranscript.upsert(entry)
					}
				}

				print("Recorded transcript entries: \(generatedTranscript.count)")
			},
		)
	}
}

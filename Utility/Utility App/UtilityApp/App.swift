// By Dennis Müller

import Dependencies
import Foundation
import FoundationModels
import OpenAI
@testable import OpenAISession
@testable import SwiftAgent
import SwiftUI

@main
struct UtilityApp: App {
	init() {
		// Enable logging for development
		SwiftAgentConfiguration.setLoggingEnabled(false)
		SwiftAgentConfiguration.setNetworkLoggingEnabled(false)
	}

	var body: some Scene {
		WindowGroup {
			Text("Hello, World!")
				.task {
					do {
						let configuration = OpenAIConfiguration.recording(apiKey: Secret.OpenAI.apiKey)
						let adapter = OpenAIAdapter(tools: Tools.all, instructions: "", configuration: configuration)
						
						let inputPrompt = Transcript<NoContext>.Prompt(input: "What is the weather in New York City, USA?", embeddedPrompt: "What is the weather in New York City, USA?")
						let initialTranscript = Transcript<NoContext>(entries: [.prompt(inputPrompt)])
						
						let stream = adapter.streamResponse(
							to: inputPrompt,
							generating: String.self,
							including: initialTranscript,
							options: .init(include: [.reasoning_encryptedContent])
						)
						
						var generatedTranscript = Transcript<NoContext>()
						
						for try await event in stream {
							switch event {
							case let .transcript(entry):
								generatedTranscript.upsert(entry)
							default:
								break
							}
						}
						
						print(generatedTranscript)
					} catch {
						
					}
				}
		}
	}
}

// MARK: - Tools

#tools(accessLevel: .private) {
	WeatherTool()
}

private struct WeatherTool: SwiftAgentTool {
	var name: String = "get_weather"
	var description: String = "Get current temperature for a given location."
	
	@Generable
	struct Arguments {
		var location: String
	}
	
	func call(arguments: Arguments) async throws -> String {
		"Sunny"
	}
}

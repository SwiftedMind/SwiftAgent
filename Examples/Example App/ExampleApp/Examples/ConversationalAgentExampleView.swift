// By Dennis Müller

import OpenAISession
import SimulatedSession
import SwiftUI

struct ConversationalAgentExampleView: View {
	@State private var userInput = "Compute 234 + 6 using the tool!"
	@State private var transcript: Transcript.PartiallyResolved<OpenAISession> = .init([])
	@State private var session: OpenAISession?

	// MARK: - Body

	var body: some View {
		Form {
			Button("Send") {
				Task {
					try await sendMessage()
				}
			}
			ForEach(transcript) { entry in
				switch entry {
				case let .prompt(prompt):
					Text("Prompt: \(prompt.input)")
				case let .reasoning(reasoning):
					Text("Reasoning: \(reasoning.summary.joined(separator: ", "))")
				case let .toolRun(toolRun):
					switch toolRun.resolution {
					case let .weather(weatherRun):
						Text("Weather Run: \(weatherRun.arguments)")
					default:
						Text("Calculator")
					}
					Text("Tool Run: \(toolRun.toolName)")
				case let .response(response):
					Text("Response: \(response)")
				}
			}
		}
//			.animation(.default, value: transcript)
		.formStyle(.grouped)
		.onAppear(perform: setupAgent)
	}

	// MARK: - Setup

	private func setupAgent() {
		session = OpenAISession(
			instructions: """
			You are a helpful assistant with access to several tools.
			Use the available tools when appropriate to help answer questions.
			Be concise but informative in your responses.
			""",
			configuration: .direct(apiKey: Secret.OpenAI.apiKey)
		)
	}

	// MARK: - Actions

	private func sendMessage() async {
		guard let session, userInput.isEmpty == false else { return }
		
		
		do {
			try await session.respond(to: userInput)
			let stream = try session.streamResponse(to: userInput, groundingWith: [.currentDate(Date())]) { input, sources in
				PromptTag("context") {
					for source in sources {
						switch source {
						case let .currentDate(date):
							PromptTag("current-date") { date }
						}
					}
				}

				PromptTag("input") {
					input
				}
			}

			for try await snapshot in stream {
				let partiallyResolvedTranscript = try snapshot.transcript.partiallyResolved(in: session)
				print(partiallyResolvedTranscript)
				transcript = partiallyResolvedTranscript
			}
		} catch {
			print("Error", error.localizedDescription)
		}
	}
}

// MARK: - Prompt Context

// enum ContextSource: PromptContextSource {
//	case currentDate(Date)
// }

#Preview {
	NavigationStack {
		ConversationalAgentExampleView()
			.navigationTitle("Agent Playground")
			.navigationBarTitleDisplayMode(.inline)
	}
	.preferredColorScheme(.dark)
}

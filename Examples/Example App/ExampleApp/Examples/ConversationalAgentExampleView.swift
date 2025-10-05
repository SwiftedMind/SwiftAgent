// By Dennis Müller

import OpenAISession
import SimulatedSession
import SwiftUI

struct ConversationalAgentExampleView: View {
	@State private var userInput = "Compute 234 + 6 using the tool! And write a short poem about the result."
	@State private var streamingTranscript: OpenAISession.ResolvedTranscript = .init()
	@State private var session: OpenAISession?

	// MARK: - Body

	var body: some View {
		List {
			if let session {
				content(session: session)
			}
		}
		.listStyle(.plain)
		.animation(.default, value: session?.transcript)
		.animation(.default, value: streamingTranscript)
		.onAppear(perform: setupAgent)
		.safeAreaBar(edge: .bottom) {
			GlassEffectContainer {
				HStack(alignment: .bottom) {
					TextField("Message", text: $userInput, axis: .vertical)
						.padding(.horizontal)
						.padding(.vertical, 10)
						.frame(maxWidth: .infinity, alignment: .leading)
						.frame(minHeight: 45)
						.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 45 / 2))
					Button {
						Task {
							await sendMessage()
						}
					} label: {
						Image(systemName: "arrow.up")
							.frame(width: 45, height: 45)
					}
					.glassEffect(.regular.interactive())
				}
			}
			.padding(.horizontal)
			.padding(.bottom, 10)
		}
	}

	@ViewBuilder
	private func content(session: OpenAISession) -> some View {
		ForEach(streamingTranscript) { entry in
			switch entry {
			case let .prompt(prompt):
				Text(prompt.input)
			case let .reasoning(reasoning):
				Text(reasoning.summary.joined(separator: ", "))
					.foregroundStyle(.secondary)
			case let .toolRun(toolRun):
				switch toolRun.resolution {
				case let .inProgress(inProgressRun):
					switch inProgressRun {
					case let .calculator(calculatorRun):
						Text(
							"Calculator Run: \(calculatorRun.arguments.firstNumber ?? 0) \(calculatorRun.arguments.operation ?? "?") \(calculatorRun.arguments.secondNumber ?? 0)",
						)
					default:
						Text("Weather Run: \(toolRun)")
					}
				case let .completed(completedRun):
					switch completedRun {
					case let .calculator(calculatorRun):
						Text(
							"Calculator Run: \(calculatorRun.arguments.firstNumber) \(calculatorRun.arguments.operation) \(calculatorRun.arguments.secondNumber)",
						)
					default:
						Text("Weather Run: \(toolRun)")
					}
				case let .failed(failedRun):
					Text("Failed Run: \(failedRun)")
				}
			case let .response(response):
				if let text = response.text {
					Text(text)
				}
			}
		}
	}

	// MARK: - Actions

	private func sendMessage() async {
		guard let session, userInput.isEmpty == false else { return }

		do {
			let options = OpenAIGenerationOptions(
				include: [.reasoning_encryptedContent],
				reasoning: .init(effort: .medium, summary: .auto),
			)

			let stream = try session.streamResponse(
				to: userInput,
				groundingWith: [.currentDate(Date())],
				options: options,
			) { input, sources in
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
				streamingTranscript = snapshot.streamingTranscript
				// throttling
				try await Task.sleep(for: .seconds(0.1))
				print(streamingTranscript)
			}

//			streamingTranscript = .init()
		} catch {
			print("Error", error.localizedDescription)
		}
	}

	private func setupAgent() {
		session = OpenAISession(
			instructions: """
			You are a helpful assistant with access to several tools.
			Use the available tools when appropriate to help answer questions.
			Be concise but informative in your responses.
			""",
			configuration: .direct(apiKey: Secret.OpenAI.apiKey),
		)
	}
}

#Preview {
	NavigationStack {
		ConversationalAgentExampleView()
			.navigationTitle("Agent Playground")
			.navigationBarTitleDisplayMode(.inline)
	}
	.preferredColorScheme(.dark)
}

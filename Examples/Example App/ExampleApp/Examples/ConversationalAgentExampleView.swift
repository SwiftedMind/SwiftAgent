// By Dennis Müller

import OpenAISession
import SimulatedSession
import SwiftUI

// TODO: Views must handle partial tool runs and finished tool runs?

struct ConversationalAgentExampleView: View {
	@State private var userInput = "Compute 234 + 6 using the tool!"
	@State private var streamingTranscript: OpenAISession.StreamingTranscript = .init()
	@State private var session: OpenAISession?

	// MARK: - Body

	var body: some View {
		List {
			ForEach(session?.resolvedTranscript ?? .init()) { entry in
				switch entry {
				case let .prompt(prompt):
					Text(prompt.input)
				case let .reasoning(reasoning):
					Text(reasoning.summary.joined(separator: ", "))
						.foregroundStyle(.secondary)
				case let .toolRun(toolRun):
					switch toolRun.resolution {
					case let .calculator(calculatorRun):
						Text(
							"Calculator Run: \(calculatorRun.arguments.firstNumber) \(calculatorRun.arguments.operation) \(calculatorRun.arguments.secondNumber)",
						)
					default:
						Text("Weather Run: \(toolRun)")
					}
					Text("Tool Run: \(toolRun.toolName)")
				case let .response(response):
					if let text = response.text {
						Text(text)
					}
				}
			}
			ForEach(streamingTranscript) { entry in
				switch entry {
				case let .prompt(prompt):
					Text(prompt.input)
				case let .reasoning(reasoning):
					Text(reasoning.summary.joined(separator: ", "))
						.foregroundStyle(.secondary)
				case let .toolRun(toolRun):
					switch toolRun.resolution {
					case let .calculator(calculatorRun):
						Text(
							"Calculator Run: \(calculatorRun.arguments.firstNumber) \(calculatorRun.arguments.operation) \(calculatorRun.arguments.secondNumber)",
						)
					default:
						Text("Weather Run: \(toolRun)")
					}
					Text("Tool Run: \(toolRun.toolName)")
				case let .response(response):
					if let text = response.text {
						Text(text)
					}
				}
			}
		}
		.task {
			let transcriptStream = Observations {
				session?.transcript
			}

			for await transcript in transcriptStream {
				print("QQQ", transcript)
			}
			print("ABCCC")
		}
		.listStyle(.plain)
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

	// MARK: - Setup

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
			}

			streamingTranscript = .init([])
		} catch {
			print("Error", error.localizedDescription)
		}
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

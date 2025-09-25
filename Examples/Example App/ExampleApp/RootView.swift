// By Dennis Müller

import OpenAISession
import SimulatedSession
import SwiftUI

struct RootView: View {
	@State private var userInput = ""
	@State private var agentResponse = ""
	@State private var toolCallsUsed: [String] = []
	@State private var isLoading = false
	@State private var errorMessage: String?
	@State private var session: OpenAIContextualSession<ContextSource>?

	// MARK: - Body

	var body: some View {
		NavigationStack {
			Form {
				Section("Agent") {
					TextField("Ask me anything…", text: $userInput, axis: .vertical)
						.lineLimit(3...6)
						.submitLabel(.send)
						.disabled(isLoading)
						.onSubmit {
							Task { await askAgent() }
						}

					Button {
						Task { await askAgent() }
					} label: {
						Text("Ask Agent")
					}
					.disabled(isLoading || userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
				}

				if isLoading {
					Section {
						HStack {
							ProgressView()
							Text("Thinking…")
						}
						.foregroundStyle(.secondary)
					}
				}

				if let errorMessage {
					Section("Error") {
						Label {
							Text(errorMessage)
						} icon: {
							Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
						}
						.accessibilityLabel(String(localized: "Error"))
					}
				}

				if !agentResponse.isEmpty {
					Section("Response") {
						Text(agentResponse)
							.textSelection(.enabled)
					}
				}

				if !toolCallsUsed.isEmpty {
					Section("Tools Used") {
						ForEach(toolCallsUsed, id: \.self) { call in
							Text(call)
						}
					}
				}
			}
			.animation(.default, value: isLoading)
			.animation(.default, value: toolCallsUsed)
			.animation(.default, value: errorMessage)
			.animation(.default, value: agentResponse)
			.navigationTitle("SwiftAgent")
			.navigationBarTitleDisplayMode(.inline)
			.formStyle(.grouped)
		}
		.task { setupAgent() }
	}

	// MARK: - Setup

	private func setupAgent() {
		session = ModelSession.openAI(
			tools: Tools.all,
			instructions: """
			You are a helpful assistant with access to several tools.
			Use the available tools when appropriate to help answer questions.
			Be concise but informative in your responses.
			""",
			context: ContextSource.self,
			configuration: .direct(apiKey: Secret.OpenAI.apiKey)
		)
	}

	// MARK: - Actions

	@MainActor
	private func askAgent() async {
		guard let session, !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

		isLoading = true
		errorMessage = nil
		agentResponse = ""
		toolCallsUsed = []

		do {
			let response = try await session.respond(to: userInput, supplying: [.currentDate(Date())]) { input, context in
				PromptTag("context") {
					for source in context.sources {
						switch source {
						case let .currentDate(date):
							PromptTag("current-date") { date }
						}
					}
					for linkPreview in context.linkPreviews {
						PromptTag("url-info", attributes: ["title": linkPreview.title ?? ""])
					}
				}

				PromptTag("input") {
					input
				}
			}

			agentResponse = response.content
			userInput = ""

			if let resolvedTranscript = session.transcript.resolved(using: Tools.all) {
				toolCallsUsed = resolvedTranscript.compactMap { entry in
					guard case let .toolRun(toolRun) = entry else {
						return nil
					}

					switch toolRun.resolution {
					case let .calculator(run):
						if let output = run.output {
							return "Calculator: \(output.expression)"
						}
						return "Calculator: \(run.arguments.firstNumber) \(run.arguments.operation) \(run.arguments.secondNumber)"
					case let .weather(run):
						guard let output = run.output else {
							return "Weather: fetching conditions for \(run.arguments.location)…"
						}

						return "Weather: \(output.location) - \(output.temperature)°C, \(output.condition)"
					}
				}
			}
		} catch {
			errorMessage = error.localizedDescription
		}

		isLoading = false
	}
}

#Preview {
	NavigationStack {
		RootView()
	}
	.preferredColorScheme(.dark)
}

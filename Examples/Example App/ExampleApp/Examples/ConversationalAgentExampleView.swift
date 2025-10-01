// By Dennis Müller

import OpenAISession
import SimulatedSession
import SwiftUI

struct ConversationalAgentExampleView: View {
	@State private var userInput = ""
//	@State private var transcript: Transcript<ContextSource>.PartiallyResolved<Resolver> = .init([])
//	@State private var session: OpenAIContextualSession<ContextSource>?

	// MARK: - Body

	var body: some View {
		Form {}
//			.animation(.default, value: transcript)
			.formStyle(.grouped)
			.onAppear(perform: setupAgent)
	}

	// MARK: - Setup

	private func setupAgent() {
//		session = ModelSession.openAI(
//			tools: Tools.all,
//			instructions: """
//			You are a helpful assistant with access to several tools.
//			Use the available tools when appropriate to help answer questions.
//			Be concise but informative in your responses.
//			""",
//			context: ContextSource.self,
//			configuration: .direct(apiKey: Secret.OpenAI.apiKey),
//		)
	}

	// MARK: - Actions

	private func sendMessage() async {
//		guard let session, userInput.isEmpty == false else { return }

//		do {
//			let stream = await session.streamResponse(to: userInput, supplying: [.currentDate(Date())]) { input, context in
//				PromptTag("context") {
//					for source in context.sources {
//						switch source {
//						case let .currentDate(date):
//							PromptTag("current-date") { date }
//						}
//					}
//					for linkPreview in context.linkPreviews {
//						PromptTag("url-info", attributes: ["title": linkPreview.title ?? ""])
//					}
//				}
//
//				PromptTag("input") {
//					input
//				}
//			}

//			userInput = ""

//			for try await snapshot in stream {
//				if let partiallyResolvedTranscript = snapshot.transcript.partiallyResolved(using: Tools.all) {
//					transcript = partiallyResolvedTranscript
//				}
//			}

//		} catch {
//			print("Error", error.localizedDescription)
//		}
	}
}

// MARK: - Prompt Context

//enum ContextSource: PromptContextSource {
//	case currentDate(Date)
//}

#Preview {
	NavigationStack {
		ConversationalAgentExampleView()
			.navigationTitle("Agent Playground")
			.navigationBarTitleDisplayMode(.inline)
	}
	.preferredColorScheme(.dark)
}

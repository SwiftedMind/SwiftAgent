// By Dennis Müller

import OpenAISession
import SimulatedSession
import SwiftUI
import UIKit

/*

 TODOS

 - Updating transcript in session vs only retuning it in the stream method
    -> transcript always updates as soon as new data arrives, in both non-streaming and streaming methods
 -> So it's always fine to observe the transcript and ignore AgentResponse / AgentSnapshot data
 -> So you can either observe the transcript and ignore the response, or observe the response (managing your own transcript state) and ignore the transcript
 -> Thought. Maybe it's fine to not stream the transcript but only the output once it starts arriving?
 - Remove streaming transcript, since it's nw unified
 - Make the throttling properly configurable with presets and custom values
 - Can the resolved transcript even work? the response structured output is on a method basis, so it can't ever be resolved inside the transcript itself
 - But if you then go for the observe session.transcript way, you never have access to the structured output directly

 -> Maybe have something similar to tool resolution. You define @StructuredOutput(SomeGenerable.self) var weatherReport, and then it can be somehow decoded from the transcript's structured response.

 The provider macro would then generate an enum ResolvedStructuredOutput<Provider> that you can iterate over in the view to get the structured output. And maybe if there is just one, it's not an enum but the type directly, for convenience?

 Problem: tools have names to identify them, the structured output stuff doesn't
 -> Bake it into the transcript since we know the name when calling the method (synthesized from property name)
 -> But I need to figure out how the api does structured outputs. -> Simply decode all .structured responses into the type. In practice it should only ever be one, but just in case, map everything.

 in session:

 This is passed  as the "generating:" parameter to the session.streamResponse method (generating: .weatherReport)
 enum XYZ: String {
  case weatherReport = "weatherReport"
 }

 passing nil means string response (makes it also easier to check for the output type)

 func decodeStructuredOutput(name: String, content: GeneratedContent) -> ResolvedStructuredOutput<Provider> {
  switch name {
  case "WeatherReport":
 // decode
    return ResolvedStructuredOutput.weatherReport(decodedContent)
  default:
    return content
  }
 }

 */

struct ConversationalAgentExampleView: View {
  @State private var userInput = "Compute 234 + 6 using the tool! And write a 10 paragraph story about the result. Just write the story!"
  @State private var streamingTranscript: OpenAISession.ResolvedTranscript = .init()
  @State private var session: OpenAISession?

  // MARK: - Body

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        if let session {
          content(session: session)
        }
      }
      .padding(.horizontal)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .defaultScrollAnchor(.bottom)
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
      .padding()
    }
  }

  @ViewBuilder
  private func content(session: OpenAISession) -> some View {
    ForEach(streamingTranscript) { entry in
      switch entry {
      case let .prompt(prompt):
        PromptEntryView(prompt: prompt)
      case let .reasoning(reasoning):
        ReasoningEntryView(reasoning: reasoning)
      case let .toolRun(toolRun):
        ToolRunEntryView(toolRun: toolRun)
      case let .response(response):
        ResponseEntryView(response: response)
      }
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

  // MARK: - Actions

  private func sendMessage() async {
    guard let session, userInput.isEmpty == false else { return }

    let userInput = userInput
    self.userInput = ""

    do {
      let options = OpenAIGenerationOptions(
        include: [.reasoning_encryptedContent],
        reasoning: .init(effort: .minimal, summary: .auto),
      )

      // let stream = try session.streamResponse(
      //   to: userInput,
      //   generating: String.self,
      //   groundingWith: [.currentDate(Date())],
      //   using: OpenAIModel.gpt5_nano,
      //   options: options,
      // ) { input, sources in
      //   PromptTag("context") {
      //     for source in sources {
      //       switch source {
      //       case let .currentDate(date):
      //         PromptTag("current-date") { date }
      //       }
      //     }
      //   }

      //   PromptTag("input") {
      //     input
      //   }
      // }

      // for try await snapshot in stream {
      //   streamingTranscript = snapshot.streamingTranscript
      // }

      //			streamingTranscript = .init()
    } catch {
      print("Error", error.localizedDescription)
    }
  }
}

// MARK: - Entry Views

private struct PromptEntryView: View {
  let prompt: OpenAISession.ResolvedTranscript.Prompt

  var body: some View {
    Text(prompt.input)
  }
}

private struct ReasoningEntryView: View {
  let reasoning: OpenAISession.ResolvedTranscript.Reasoning

  var body: some View {
    Text(reasoning.summary.joined(separator: ", "))
      .foregroundStyle(.secondary)
  }
}

private struct ToolRunEntryView: View {
  let toolRun: OpenAISession.ResolvedToolRun

  var body: some View {
    Text("TODO")
    // switch toolRun.resolution {
    // case let .inProgress(inProgressRun):
    // 	switch inProgressRun {
    // 	case let .calculator(calculatorRun):
    // 		Text(
    // 			"Calculator Run: \(calculatorRun.arguments.firstNumber ?? 0) \(calculatorRun.arguments.operation ?? "?")
    // 			\(calculatorRun.arguments.secondNumber ?? 0)",
    // 		)
    // 	default:
    // 		Text("Weather Run: \(toolRun.toolName)")
    // 	}
    // case let .completed(completedRun):
    // 	switch completedRun {
    // 	case let .calculator(calculatorRun):
    // 		Text("TODO")
    // 	// Text(
    // 	// 	"Calculator Run: \(calculatorRun.arguments.firstNumber) \(calculatorRun.arguments.operation)
    // 	// 	\(calculatorRun.arguments.secondNumber)",
    // 	// )
    // 	default:
    // 		Text("Weather Run: \(toolRun.toolName)")
    // 	}
    // case let .failed(failedRun):
    // 	Text("Failed Run: \(String(describing: failedRun))")
    // }
  }
}

private struct ResponseEntryView: View {
  let response: OpenAISession.ResolvedTranscript.Response

  var body: some View {
    if let text = response.text {
      HorizontalGeometryReader { width in
        UILabelView(
          string: text,
          preferredMaxLayoutWidth: width,
        )
      }
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

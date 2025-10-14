// By Dennis Müller

import struct FoundationModels.GeneratedContent
import OpenAISession
import SimulatedSession
import SwiftUI
import UIKit

/*

 TODO: More unit tests.
 TODO: Go through the API flow and check if this is now somewhat final
      -> Do this by finally building the example app properly
 TODO: Start writing new documentation
 TODO: Changelog
 */

struct ConversationalAgentExampleView: View {
  @State private var userInput = "Compute 234 + 6 using the tool! And write a 10 paragraph story about the result. Just write the story!"
  @State private var transcript: OpenAISession.DecodedTranscript = .init()
  @State private var streamingTranscript: OpenAISession.DecodedTranscript = .init()
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
    ForEach(transcript + streamingTranscript) { entry in
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

    Task {
      // print("NOW")
      // let test = try await session!.weatherReport.respond(to: "Make up a weather report")
      // print(test.content)
    }
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

      let stream = try session.streamResponse(
        to: userInput,
        groundingWith: [.currentDate(Date())],
        using: OpenAIModel.gpt5_nano,
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

      let decoder = session.decoder()
      for try await snapshot in stream {
        streamingTranscript = try decoder.decode(snapshot.transcript)
      }

      transcript += streamingTranscript
      streamingTranscript = .init()
    } catch {
      print("Error", error.localizedDescription)
    }
  }
}

// MARK: - Entry Views

private struct PromptEntryView: View {
  let prompt: OpenAISession.DecodedTranscript.Prompt

  var body: some View {
    Text(prompt.input)
  }
}

private struct ReasoningEntryView: View {
  let reasoning: OpenAISession.DecodedTranscript.Reasoning

  var body: some View {
    Text(reasoning.summary.joined(separator: ", "))
      .foregroundStyle(.secondary)
  }
}

private struct ToolRunEntryView: View {
  let toolRun: OpenAISession.DecodedToolRun

  var body: some View {
    switch toolRun {
    case let .calculator(calculatorRun):
      CalculatorToolRunView(calculatorRun: calculatorRun)
    case let .weather(weatherRun):
      switch weatherRun.arguments {
      case let .final(arguments):
        Text("Weather Run: \(arguments.location, default: "?")")
      case let .partial(arguments):
        Text("Weather Run: \(arguments.location, default: "?")")
      case let .failed(error):
        Text("Weather Run: \(error, default: "?")")
      }
    case let .unknown(toolCall):
      Text("Unknown Run: \(toolCall.toolName)")
    }
  }
}

private struct CalculatorToolRunView: View {
  var calculatorRun: ToolRun<CalculatorTool>

  var body: some View {
    if let arguments = calculatorRun.normalizedArguments {
      Text(
        "Calculator Run: \(arguments.firstNumber?.formatted() ?? "?") \(arguments.operation ?? "?") \(arguments.secondNumber?.formatted() ?? "?")",
      )
    } else if case let .failed(error) = calculatorRun.arguments {
      Text("Calculator Run: \(error, default: "?")")
    } else {
      Text("Calculator Run: Pending arguments")
        .foregroundStyle(.secondary)
    }
  }
}

private struct ResponseEntryView: View {
  let response: OpenAISession.DecodedTranscript.Response

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

// TODO: Must define this outside the #Preview macro, because inside of it, we don't have access to the generated code
let mockToolRun = OpenAISession.DecodedToolRun.calculator(.mockPartial)

#Preview {
  NavigationStack {
    ToolRunEntryView(toolRun: mockToolRun)
      .navigationTitle("Agent Playground")
      .navigationBarTitleDisplayMode(.inline)
  }
  .preferredColorScheme(.dark)
}

#Preview {
  NavigationStack {
    ConversationalAgentExampleView()
      .navigationTitle("Agent Playground")
      .navigationBarTitleDisplayMode(.inline)
  }
  .preferredColorScheme(.dark)
}

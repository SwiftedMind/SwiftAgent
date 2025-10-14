// By Dennis Müller

import OpenAISession
import SimulatedSession
import SwiftUI
import UIKit

struct ConversationalAgentExampleView: View {
  @State private var userInput = "Choose a random city and request a weather report. Then use the calculator to multiply the temperature by 5 and finally answer with a short story (1-2 paragraphs) involving the tool call outputs in some funny way."
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
      WeatherToolRunView(weatherRun: weatherRun)
    case let .unknown(toolCall):
      Text("Unknown Run: \(toolCall.toolName)")
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

#Preview {
  NavigationStack {
    ConversationalAgentExampleView()
      .navigationTitle("Agent Playground")
      .navigationBarTitleDisplayMode(.inline)
  }
  .preferredColorScheme(.dark)
}

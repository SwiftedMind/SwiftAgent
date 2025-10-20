// By Dennis Müller

import OpenAISession
import SwiftUI
import UIKit

struct AgentPlaygroundView: View {
  @State private var userInput = """
  Choose a random city and request a weather report. Then use the calculator to
  multiply the temperature by 5 and finally answer with a short story (1-2 paragraphs) involving the tool call
  outputs in some funny way.
  """
  @State private var transcript: Transcript.Resolved<SessionSchema> = .init()
  @State private var streamingTranscript: Transcript.Resolved<SessionSchema> = .init()
  @State private var sessionSchema = SessionSchema()
  @State private var session: OpenAISession<SessionSchema>?

  @State private var viewState: ViewState = .idle
  @State private var messageTask: Task<Void, Never>?
  @State private var error: (any Error)?

  // MARK: - Body

  var body: some View {
    NavigationStack {
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
      .onAppear(perform: setupAgent)
      .safeAreaBar(edge: .bottom) {
        if let error {
          Text(error.localizedDescription)
            .font(.callout)
            .foregroundStyle(.red)
            .transition(.opacity.combined(with: .scale))
        }
      }
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
              messageTask?.cancel()
              messageTask = Task {
                await sendMessage()
              }
            } label: {
              if viewState == .loading {
                ProgressView()
                  .frame(width: 45, height: 45)
                  .transition(.opacity.combined(with: .scale))
              } else {
                Image(systemName: "arrow.up")
                  .frame(width: 45, height: 45)
                  .transition(.opacity.combined(with: .scale))
              }
            }
            .glassEffect(.regular.interactive())
          }
        }
        .padding()
      }
      .animation(.default, value: streamingTranscript)
      .animation(.default, value: viewState)
      .navigationTitle("Agent Playground")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  @ViewBuilder
  private func content(session: OpenAISession<SessionSchema>) -> some View {
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
      schema: sessionSchema,
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
    viewState = .loading

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

      let resolver = sessionSchema.transcriptResolver()
      for try await snapshot in stream {
        streamingTranscript = try resolver.resolve(snapshot.transcript)
      }

      transcript += streamingTranscript
      streamingTranscript = .init()
      viewState = .idle
    } catch {
      print("Error", error.localizedDescription)
      viewState = .error
      self.error = error
    }
  }
}

// MARK: - Entry Views

private struct PromptEntryView: View {
  let prompt: Transcript.Resolved<SessionSchema>.Prompt

  var body: some View {
    Text(prompt.input)
  }
}

private struct ReasoningEntryView: View {
  let reasoning: Transcript.Resolved<SessionSchema>.Reasoning

  var body: some View {
    Text(reasoning.summary.joined(separator: ", "))
      .foregroundStyle(.secondary)
  }
}

private struct ToolRunEntryView: View {
  let toolRun: SessionSchema.DecodedToolRun

  var body: some View {
    switch toolRun {
    case let .calculator(calculatorRun):
      CalculatorToolRunView(calculatorRun: calculatorRun)
    case let .weather(weatherRun):
      WeatherToolRunView(weatherRun: weatherRun)
    case let .unknown(toolCall):
      GroupBox("Unknown Tool") {
        Text(toolCall.toolName)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}

private struct ResponseEntryView: View {
  let response: Transcript.Resolved<SessionSchema>.Response

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

// MARK: - Helpers

private enum ViewState: Hashable {
  case idle
  case loading
  case error
}

#Preview {
  AgentPlaygroundView()
    .preferredColorScheme(.dark)
}

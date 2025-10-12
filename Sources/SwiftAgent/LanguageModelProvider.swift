// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public protocol LanguageModelProvider<Adapter>: AnyObject, Sendable {
  /// The transcript type for this session, containing the conversation history.
  typealias Transcript = SwiftAgent.Transcript
  typealias DecodedTranscript = Transcript.Decoded<Self>
  typealias Response<Content: Generable> = AgentResponse<Content, Self>
  typealias Snapshot<Content: Generable> = AgentSnapshot<Content, Self>

  associatedtype Adapter: SwiftAgent.Adapter & SendableMetatype
  associatedtype DecodedGrounding: SwiftAgent.DecodedGrounding
  associatedtype DecodedToolRun: SwiftAgent.DecodedToolRun
  associatedtype DecodedStructuredOutput: SwiftAgent.DecodedStructuredOutput

  nonisolated static var structuredOutputs: [any (SwiftAgent.DecodableStructuredOutput<Self>).Type] { get }
  nonisolated var tools: [any DecodableTool<Self>] { get }

  var adapter: Adapter { get }
  @MainActor var transcript: Transcript { get set }
  @MainActor var tokenUsage: TokenUsage { get set }

  @MainActor func resetTokenUsage()
  nonisolated func decoder() -> TranscriptDecoder<Self>

  @discardableResult
  nonisolated func withAuthorization<T>(
    token: String,
    refresh: (@Sendable () async throws -> String)?,
    perform: () async throws -> T,
  ) async rethrows -> T
}

public protocol DecodedGrounding: Sendable, Equatable, Codable {}

public protocol DecodedStructuredOutput: Sendable, Equatable {
  static func makeUnknown(segment: Transcript.StructuredSegment) -> Self
}

public protocol DecodedToolRun: Identifiable, Equatable, Sendable where ID == String {
  var id: String { get }
  static func makeUnknown(toolCall: Transcript.ToolCall) -> Self
}

// MARK: - Default Implementations

package extension LanguageModelProvider {
  nonisolated func encodeGrounding(_ grounding: [DecodedGrounding]) throws -> Data {
    try JSONEncoder().encode(grounding)
  }
}

package extension LanguageModelProvider {
  // MARK: - Private Response Helpers

  @MainActor
  func appendTranscript(_ entry: Transcript.Entry) {
    transcript.append(entry)
  }

  @MainActor
  func appendTranscript(_ entries: [Transcript.Entry]) {
    transcript.append(contentsOf: entries)
  }

  @MainActor
  func upsertTranscript(_ entry: Transcript.Entry) {
    transcript.upsert(entry)
  }

  @MainActor
  func mergeTokenUsage(_ usage: TokenUsage) {
    tokenUsage.merge(usage)
  }

  func processResponse<Content>(
    from prompt: Transcript.Prompt,
    generating type: (some StructuredOutput<Content>).Type?,
    using model: Adapter.Model,
    options: Adapter.GenerationOptions?,
  ) async throws -> Response<Content> where Content: Generable {
    let promptEntry = Transcript.Entry.prompt(prompt)
    await appendTranscript(promptEntry)

    let stream = await adapter.respond(
      to: prompt,
      generating: type,
      using: model,
      including: transcript,
      options: options ?? .automatic(for: model),
    )

    var generatedTranscript = Transcript()
    var generatedUsage: TokenUsage?

    for try await update in stream {
      try Task.checkCancellation()

      switch update {
      case let .transcript(entry):
        await upsertTranscript(entry)
        generatedTranscript.upsert(entry)

        // Handle content extraction based on type
        if Content.self == String.self {
          // For String content, we accumulate all text segments and process at the end
          continue
        } else {
          // For structured content, return immediately when we find a structured segment
          if case let .response(response) = entry {
            for segment in response.segments {
              switch segment {
              case .text:
                // Not applicable for structured content
                break
              case let .structure(structuredSegment):
                // We can return here since a structured response can only happen once
                // TODO: Handle errors here in some way

                return try Response<Content>(
                  content: Content(structuredSegment.content),
                  transcript: generatedTranscript,
                  tokenUsage: generatedUsage,
                )
              }
            }
          }
        }
      case let .tokenUsage(usage):
        // Update session token usage immediately for real-time tracking
        await mergeTokenUsage(usage)

        if var current = generatedUsage {
          current.merge(usage)
          generatedUsage = current
        } else {
          generatedUsage = usage
        }
      }
    }

    // If the task was cancelled during the stream, the stream simply ends so we need to check for cancellation here
    try Task.checkCancellation()

    // Handle final content extraction for String type
    if Content.self == String.self {
      let finalResponseSegments = generatedTranscript
        .compactMap { entry -> [String]? in
          guard case let .response(response) = entry else { return nil }

          return response.segments.compactMap { segment in
            if case let .text(textSegment) = segment {
              return textSegment.content
            }
            return nil
          }
        }
        .flatMap(\.self)

      return Response<Content>(
        content: finalResponseSegments.joined(separator: "\n") as! Content,
        transcript: generatedTranscript,
        tokenUsage: generatedUsage,
      )
    } else {
      // For structured content, if we reach here, no structured segment was found
      let errorContext = GenerationError.UnexpectedStructuredResponseContext()
      throw GenerationError.unexpectedStructuredResponse(errorContext)
    }
  }

  func processResponse(
    from prompt: Transcript.Prompt,
    using model: Adapter.Model,
    options: Adapter.GenerationOptions?,
  ) async throws -> Response<String> {
    try await processResponse(
      from: prompt,
      generating: nil as String.Type?,
      using: model,
      options: options,
    )
  }

  func processResponseStream<Content: Generable>(
    from prompt: Transcript.Prompt,
    generating type: (some StructuredOutput<Content>).Type?,
    using model: Adapter.Model,
    options: Adapter.GenerationOptions?,
  ) -> AsyncThrowingStream<Snapshot<Content>, any Error> {
    let setup = AsyncThrowingStream<AgentSnapshot<Content, Self>, any Error>.makeStream()

    let task = Task<Void, Never> { [continuation = setup.continuation] in
      do {
        let promptEntry = Transcript.Entry.prompt(prompt)
        await appendTranscript(promptEntry)

        let stream = await adapter.streamResponse(
          to: prompt,
          generating: type,
          using: model,
          including: transcript,
          options: options ?? .automatic(for: model),
        )

        var generatedTranscript = Transcript(entries: [promptEntry])
        var generatedUsage: TokenUsage = .zero

        // TODO: Make throttle configurable
        // Throttle-latest: emit at most once per interval with the freshest state
        let clock = ContinuousClock()
        let throttleInterval: Duration = .seconds(0.1)
        var nextEmitDeadline = clock.now

        for try await update in stream {
          switch update {
          case let .transcript(entry):
            generatedTranscript.upsert(entry)

          case let .tokenUsage(usage):
            generatedUsage.merge(usage)
          }

          // Throttle-latest: emit at most once per interval with the freshest state
          let now = clock.now
          if now >= nextEmitDeadline {
            continuation.yield(
              Snapshot(
                content: nil,
                transcript: generatedTranscript,
                tokenUsage: generatedUsage,
              ),
            )

            // Update the provider's transcript and token usage when the stream is finished
            await appendTranscript(generatedTranscript.entries)
            await mergeTokenUsage(generatedUsage)

            nextEmitDeadline = now.advanced(by: throttleInterval)
          }
        }

        // Update the transcript and token usage when the stream is finished
        await appendTranscript(generatedTranscript.entries)
        await mergeTokenUsage(generatedUsage)

        // TODO: Send the final, parsed content, if type != String.self
        continuation.yield(
          Snapshot(
            content: nil,
            transcript: generatedTranscript,
            tokenUsage: generatedUsage,
          ),
        )
        continuation.finish()
      } catch {
        continuation.finish(throwing: error)
      }
    }

    setup.continuation.onTermination = { _ in
      task.cancel()
    }

    return setup.stream
  }

  func processResponseStream(
    from prompt: Transcript.Prompt,
    using model: Adapter.Model,
    options: Adapter.GenerationOptions?,
  ) -> AsyncThrowingStream<Snapshot<String>, any Error> {
    processResponseStream(from: prompt, generating: nil as String.Type?, using: model, options: options)
  }
}

// MARK: - Authorization

public extension LanguageModelProvider {
  // Executes the provided work with a temporary authorization context for this session.
  //
  // Use this helper to attach an access token to all network requests that happen during a single
  // "agent turn" — that is, every request the agent performs until it finishes producing the
  // next message (reasoning steps, tool calls and their outputs, and the final response).
  //
  // The token is stored in an internal task‑local value and is automatically picked up by adapter
  // configurations that support proxy authorization (for example, ``OpenAIConfiguration/proxy(through:)``).
  // This keeps credentials out of your app bundle and enables secure, backend‑issued, short‑lived
  // tokens that you can rotate per turn.
  //
  // You can also provide an optional `refresh` closure. If the proxy responds with `401 Unauthorized`,
  // the SDK will invoke this closure to obtain a new token and retry the failed request once.
  //
  // - Parameters:
  //   - token: The access token to authorize requests for this agent turn.
  //   - refresh: Optional closure that returns a freshly issued token when a request is unauthorized.
  //   - perform: The asynchronous work to run while the authorization context is active.
  // - Returns: The result of the `perform` closure.
  //
  // ## Example: Per‑Turn Token
  //
  // ```swift
  // // 1) Configure the session to use your proxy backend
  // let configuration = OpenAIConfiguration.proxy(through: URL(string: "https://api.your‑backend.com")!)
  // let session = LanguageModelProvider.openAI(
  //   tools: [WeatherTool(), CalculatorTool()],
  //   instructions: "You are a helpful assistant.",
  //   configuration: configuration
  // )
  //
  // // 2) Ask your backend for a short‑lived token that is valid for a single agent turn
  // let token = try await backend.issueTurnToken(for: userId)
  //
  // // 3) Run all requests for this turn with that token
  // let response = try await session.withAuthorization(token: token) {
  //   try await session.respond(to: "What's the weather in San Francisco?")
  // }
  // print(response.content)
  // ```
  //
  // ## Example: Automatic Refresh
  //
  // ```swift
  // let initial = try await backend.issueTurnToken(for: userId)
  //
  // let response = try await session.withAuthorization(
  //   token: initial,
  //   refresh: { try await backend.refreshTurnToken(for: userId) }
  // ) {
  //   try await session.respond(to: "Plan a 3‑day trip to Kyoto.")
  // }
  // ```
  @discardableResult
  nonisolated func withAuthorization<T>(
    token: String,
    refresh: (@Sendable () async throws -> String)? = nil,
    perform: () async throws -> T,
  ) async rethrows -> T {
    precondition(!token.isEmpty, "Authorization token must not be empty.")
    let context = AuthorizationContext(bearerToken: token, refreshToken: refresh)
    return try await AuthorizationContext.$current.withValue(context) {
      try await perform()
    }
  }
}

// MARK: - Session Management Methods

public extension LanguageModelProvider {
  /// Clears the entire conversation transcript.
  ///
  /// This method removes all entries from the transcript, including prompts, responses,
  /// tool calls, and tool outputs. This is useful for starting a fresh conversation
  /// while retaining the same LanguageModelProvider instance with its configuration and tools.
  ///
  /// - Note: This method does not affect token usage tracking. Use `resetTokenUsage()`
  ///   if you also want to reset the cumulative token counter.
  @MainActor func clearTranscript() {
    transcript = Transcript()
  }

  /// Resets the cumulative token usage counter to zero.
  ///
  /// This method resets all token usage statistics for the session, including
  /// total tokens, input tokens, output tokens, cached tokens, and reasoning tokens.
  /// This is useful when you want to track token usage for a specific period
  /// or after clearing the transcript.
  ///
  /// - Note: This method only affects the session's cumulative token tracking.
  ///   Individual response token usage is not affected.
  @MainActor func resetTokenUsage() {
    tokenUsage = TokenUsage()
  }

  nonisolated func decoder() -> TranscriptDecoder<Self> {
    TranscriptDecoder(for: self)
  }
}

public struct NoTools {
  public init() {}
}

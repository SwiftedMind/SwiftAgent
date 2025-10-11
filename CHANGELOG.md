# Changelog

## [Upcoming]

### Breaking Changes

- **Core Protocol Renaming**: Renamed key protocols and types for better consistency and clarity throughout the framework.
  ```swift
  // Before
  protocol AgentAdapter { ... }
  protocol AgentTool { ... }
  struct AgentTranscript<Context> { ... }
  struct AgentToolRun<Tool> { ... }
  enum AgentGenerationError { ... }

  // Now
  protocol Adapter { ... }
  protocol SwiftAgentTool { ... }
  struct Transcript<Context> { ... }
  struct ToolRun<Tool> { ... }
  enum GenerationError { ... }
  ```

### Added

- **PromptTag Single Content Initializer**: Added convenience initializer for `PromptTag` that accepts a single `PromptRepresentable` content parameter, improving API ergonomics for simple use cases.

  ```swift
  // Before: required wrapping single content in array
  PromptTag("system", content: [instructions])
  
  // Now: direct single content support
  PromptTag("system", content: instructions)
  ```

- **Secure Proxy Configuration + Per‑Turn Authorization**: Added `OpenAIConfiguration.proxy(through:)` to route all requests through your own backend, and `ModelSession.withAuthorization(token:refresh:perform:)` to attach a short‑lived token to every request that happens during a single agent turn (reasoning steps, tool calls, final output). This keeps provider credentials off device and enables safe, rotating tokens.

  ```swift
  // Configure the session to use your proxy backend
  let configuration = OpenAIConfiguration.proxy(through: URL(string: "https://your-proxy.example.com")!)
  let session = ModelSession.openAI(tools: tools, instructions: "...", configuration: configuration)

  // Obtain a per‑turn token from your backend
  let token = try await backend.issueTurnToken(for: userId)

  // Authorize all requests for this turn
  let response = try await session.withAuthorization(token: token) {
    try await session.respond(to: "Create a release announcement")
  }

  // Optional: automatically refresh on 401 and retry once
  let initial = try await backend.issueTurnToken(for: userId)
  let refreshed = try await session.withAuthorization(
    token: initial,
    refresh: { try await backend.refreshTurnToken(for: userId) }
  ) {
    try await session.respond(to: "Draft a follow‑up email")
  }
  ```

- **Recoverable Tool Problems**: Added a `ToolRunProblem` error type so tools can return a recoverable issue back to the agent without stopping the loop; the OpenAI adapter now reads these problem objects to decide when a tool should retry or provide alternate output. `ToolRun` also exposes `problem` and `isAwaitingOutput` so decoders can surface the problem payload forwarded by the adapter whenever `SwiftAgentTool.Output` decoding fails.

  ```swift
  struct CustomerLookupTool: SwiftAgentTool {
    func call(arguments: Arguments) async throws -> Output {
      guard let customer = try await directory.loadCustomer(id: arguments.customerIdentifier) else {
        throw ToolRunProblem(
          reason: "Customer not found",
          details: [
            "issue" : "customerNotFound",
            "customerIdentifier" : arguments.customerIdentifier
          ]
        )
      }

      return Output(summary: customer.summary)
    }
  }
  ```

### Enhanced
- **MacPaw OpenAI SDK Migration**: Adopted MacPaw's `OpenAI` Swift package for request execution and removed the `MetaCodable` macro dependency, simplifying adapter maintenance and eliminating macro build overhead.
- **Code Cleanup**: Removed unused `Array<PromptContextLinkPreview>` extension that was adding unnecessary complexity to the prompt context API surface.
- **Tool Error Type Rename**: Renamed the core tool error type to `ToolRunError`.
- **Improved Tool Resolution**: Introduced the `Transcript.Decoded` type for embedding tool runs directly into a transcript you can iterate over. You can access it through `transcript.decoded(using: tools)`.

### Fixed

- **Problem Report Validation**: Tool output decoding errors now propagate unless the payload matches the recoverable `ToolRunProblem` report structure, preventing silent failures in custom tools.
- **URL Metadata Crash (LPMetadataProvider one-shot)**: Fixed a crash when fetching link preview metadata multiple times where a single `LPMetadataProvider` instance was reused. `LPMetadataProvider` is a one-shot object and must not be started more than once. `URLMetadataProvider` now creates a fresh provider per request, preventing the "Trying to start fetching on an LPMetadataProvider that has already started" error and making concurrent URL fetches safe.

## [0.6.0]

### Added

- **Session Management Methods**: Added `clearTranscript()` and `resetTokenUsage()` methods to ModelSession for better session lifecycle management.

  ```swift
  // Clear the conversation transcript while keeping the session configuration
  session.clearTranscript()
  
  // Reset cumulative token usage counter
  session.resetTokenUsage()
  
  // Both methods can be used independently or together
  session.clearTranscript()
  session.resetTokenUsage()
  ```

- **Token Usage Tracking and Reporting**: Added comprehensive token usage monitoring across all AI interactions with both per-response and session-level tracking.

  ```swift
  let response = try await session.respond(to: "What's the weather?")
  
  // Access aggregated token usage from the individual response
  if let usage = response.tokenUsage {
    print("Response tokens used: \(usage.totalTokens ?? 0)")
    print("Response input tokens: \(usage.inputTokens ?? 0)")
    print("Response output tokens: \(usage.outputTokens ?? 0)")
    print("Response cached tokens: \(usage.cachedTokens ?? 0)")
    print("Response reasoning tokens: \(usage.reasoningTokens ?? 0)")
  }
  
  // Access cumulative token usage across the entire session
  print("Session total tokens: \(session.tokenUsage.totalTokens ?? 0)")
  print("Session input tokens: \(session.tokenUsage.inputTokens ?? 0)")
  print("Session output tokens: \(session.tokenUsage.outputTokens ?? 0)")
  
  // Session token usage updates in real-time during streaming responses
  // Perfect for @Observable integration in SwiftUI for live usage monitoring
  ```

### Fixed

- **Transcript ID Handling**: Fixed issue where transcript IDs were not properly converting back to original OpenAI IDs, removing unnecessary manual addition of "fc_" prefix from function call IDs.
- **Tool Output Status Tracking**: Added missing `status` field to `ToolOutput` in `AgentTranscript` for better tool execution tracking and consistency.
- **JSON Encoding Determinism**: Enabled sorted keys in OpenAI JSON encoder to ensure consistent property ordering in tool schemas, preventing cache misses and improving prompt caching effectiveness.

## [0.5.0]

### Added

- **Simulated Sessions**: Introduced the `SimulatedSession` module for testing and development without API calls. The simulation system includes:
  - `simulateResponse` methods that mirror the standard `respond` API
  - `MockableAgentTool` protocol for creating mock tool calls and outputs
  - `SimulatedGeneration` enum supporting tool runs, reasoning, and text or structured responses, simulating model generations
  - Complete transcript compatibility - simulated responses work on the real transcript object, guaranteeing full compatibility with the actual agent
  - Zero API costs during development and testing
  
  ```swift
  import OpenAISession
  import SimulatedSession
  
  // Create mockable tool wrappers
  struct WeatherToolMock: MockableAgentTool {
    var tool: WeatherTool
    func mockArguments() -> WeatherTool.Arguments { /* mock data */ }
    func mockOutput() async throws -> WeatherTool.Output { /* mock results */ }
  }
  
  // Create an OpenAI session as normal
  let session = ModelSession.openAI(
    tools: [WeatherTool()], // Your actual tool; the mockable tool will be used below
    instructions: "You are a helpful assistant.",
    apiKey: "sk-...",
  )
  
  // And then use simulateResponse instead of respond
  let response = try await session.simulateResponse(
    to: "What's the weather?",
    generations: [
      .toolRun(tool: WeatherToolMock(tool: WeatherTool())),
      .response(content: "It's sunny!")
    ]
  )
  ```
  
- The `PromptContext` protocol has been replaced with a generic struct wrapper that provides both user-written input and app or SDK generated context data (like link previews or vector search results). User types now conform to `PromptContextSource` instead of `PromptContext`:
  ```swift
  // Define your context source
  enum ContextSource: PromptContextSource {
    case vectorSearchResult(String)
    case searchResults([String])
  }
  
  // Create a session with context support and pass the context source
  let session = ModelSession.openAI(tools: tools, context: ContextSource.self, apiKey: "sk-...")
  
  // Respond with context - user input and context are kept separated in the transcript
  let response = try await session.respond(
    to: "What are the key features of SwiftUI?",
    supplying: [
      .vectorSearchResult("SwiftUI declarative syntax..."),
      .searchResults("Apple's official SwiftUI documentation...")
    ]
  ) { input, context in
    PromptTag("context", items: context.sources)
    input
  }
  ```

- **Link Previews in Prompt Context**: The new `PromptContext` struct includes `linkPreviews` that can automatically fetch and include metadata from URLs in user inputs

- **OpenAI Generation Configuration**: The new `OpenAIGenerationOptions` type provides access to OpenAI API parameters including:
  - `include` - Additional outputs like reasoning or logprobs
  - `allowParallelToolCalls` - Control parallel tool execution
  - `reasoning` - Configuration for reasoning-capable models
  - `safetyIdentifier` - Misuse detection identifier
  - `serviceTier` - Request priority and throughput control
  - `toolChoice` - Fine-grained tool selection control
  - `topLogProbs` - Token probability information
  - `topP` - Alternative sampling method
  - `truncation` - Context window handling
  - And more OpenAI-specific options

### Changed

- **Breaking Change**: Restructured the products in the SDK. Each provider now has its own product, e.g. `OpenAISession`
  ```swift
  import OpenAISession
  ```

- **Breaking Change**: Renamed nearly all the types in the SDK to close align with FoundationModels types. `Agent` is now `ModelSession`, and `OpenAIAgent` is now `OpenAISession`:
  ```swift
  import OpenAISession
  
  // Create an OpenAI session through the ModelSession type
  let session = ModelSession.openAI(
    tools: [WeatherTool(), CalculatorTool()],
    instructions: "You are a helpful assistant.",
    apiKey: "sk-...",
  )
  ```
  
- **Breaking Change**: Replaced the generic `GenerationOptions` struct with adapter-specific generation options. Each adapter now defines its own `GenerationOptions` type as an associated type, providing better type safety and access to adapter-specific parameters:
  ```swift
  // Before
  let options = GenerationOptions(temperature: 0.7, maximumResponseTokens: 1000)
  let response = try await agent.respond(to: prompt, options: options)
  
  // Now
  let options = OpenAIGenerationOptions(temperature: 0.7, maxOutputTokens: 1000)
  let response = try await session.respond(to: prompt, options: options)
  ```

## [0.4.1]

### Fixed

- **Agent Text Response Content Formatting**: Fixed an issue with the agent's text response content formatting that could cause malformed responses
- **Tool Resolution**: Fixed a critical bug where tools would never be decoded due to mismatched IDs, ensuring proper tool call execution
- **Tool Resolution Logging**: Improved logging around tool resolution to better debug tool call issues

### Enhanced

- **Collection Protocol Conformance**: Made `AgentTranscript` and `AgentTranscript.ToolCalls` conform to the `Collection` protocol, making it easier to access their `entries` and `calls` properties and work with them using standard Swift collection methods
- **Logging System**: Added general logging methods and enhanced tool resolution logging for better debugging and monitoring
- **Example App**: Added a proper, modern example app with native SwiftUI design that demonstrates the SDK's capabilities

### Other

- **Code Cleanup**: Minor code cleanup and formatting improvements across the codebase
- **UI Modernization**: Redesigned example app UI with new tools and modern SwiftUI patterns

## [0.4.0]

### Breaking Changes

- **Renamed `Provider` to `Adapter`**: The core abstraction for AI model integrations has been renamed from `Provider` to `Adapter` for better clarity. Update all references to use the new naming:
  ```swift
  // Before
  let agent = Agent<OpenAIProvider, Context>()
  
  // Now
  let agent = Agent<OpenAIAdapter, Context>()
  ```

- **Renamed `Transcript` to `AgentTranscript`**: To avoid naming conflicts with FoundationModels, the `Transcript` type has been renamed to `AgentTranscript`:
  ```swift
  // Before
  public var transcript: Transcript
  
  // Now  
  public var transcript: AgentTranscript<Adapter.Metadata, Context>
  ```

### Added

- **Prompt Context System**: Introduced a new `PromptContext` protocol that enables separation of user input from contextual information (such as vector embeddings or retrieved documents). This provides cleaner transcript organization and better prompt augmentation:
  ```swift
  enum PromptContext: SwiftAgent.PromptContext {
    case vectorEmbedding(String)
    case documentContext(String)
  }
  
  let agent = OpenAIAgent(supplying: PromptContext.self, tools: tools)
  
  // User input and context are now separated in the transcript
  let response = try await agent.respond(
    to: "What is the weather like?", 
    supplying: [.vectorEmbedding("relevant weather data")]
  ) { input, context in
    PromptTag("context", items: context)
    input
  }
  ```

- **Tool Decoder**: Added a powerful type-safe tool resolution system that combines tool calls with their outputs. The `ToolDecoder` enables compile-time access to tool arguments and outputs:
  ```swift
  // Define a decoded tool run enum
  enum DecodedToolRun {
    case getFavoriteNumbers(AgentToolRun<GetFavoriteNumbersTool>)
  }
  
  // Tools must implement the decode method
  func decode(_ run: AgentToolRun<GetFavoriteNumbersTool>) -> DecodedToolRun {
    .getFavoriteNumbers(run)
  }
  
  // Use the tool decoder in your UI code
  let toolDecoder = agent.transcript.toolDecoder(for: tools)
  
  for entry in agent.transcript {
    if case let .toolCalls(toolCalls) = entry {
      for toolCall in toolCalls.calls {
        let decodedTool = try toolDecoder.decode(toolCall)
        switch decodedTool {
        case let .getFavoriteNumbers(run):
          print("Count:", run.arguments.count)
          if let output = run.output {
            print("Numbers:", output.numbers)
          }
        }
      }
    }
  }
  ```

- **Convenience Initializers**: Added streamlined initializers that reduce generic complexity. The new `OpenAIAgent` typealias and convenience initializers make agent creation more ergonomic:
  ```swift
  // Simplified initialization with typealias
  let agent = OpenAIAgent(supplying: PromptContext.self, tools: tools)
  
  // No context needed
  let agent = OpenAIAgent(tools: tools)
  
  // Even simpler for basic usage
  let agent = OpenAIAgent()
  ```

### Enhanced

- **AgentTool Protocol**: Extended the `AgentTool` protocol with an optional `DecodedToolRun` associated type to support the new tool decoder system
- **Type Safety**: Improved compile-time type safety for tool argument and output access through the tool decoder
- **Transcript Organization**: Better separation of concerns in transcript entries, with user input and context clearly distinguished

### Migration Guide

1. **Update Provider references**: Replace all instances of `Provider` with `Adapter` in your code
2. **Update Transcript references**: Replace `Transcript` with `AgentTranscript` where needed
3. **Consider adopting PromptContext**: If you're currently building prompts with embedded context outside the agent, consider migrating to the new `PromptContext` system for cleaner separation
4. **Adopt Tool Decoder**: For better type safety in UI code that displays tool runs, implement the `decode` method in your tools and use the transcript's `toolDecoder`
5. **Use convenience initializers**: Simplify your agent initialization code using the new `OpenAIAgent` typealias and convenience initializers

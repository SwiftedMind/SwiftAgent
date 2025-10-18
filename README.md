
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FSwiftedMind%2FSwiftAgent%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/SwiftedMind/SwiftAgent)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FSwiftedMind%2FSwiftAgent%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/SwiftedMind/SwiftAgent)

# SwiftAgent

**Native Swift SDK for building autonomous AI agents with Apple's FoundationModels design philosophy**

SwiftAgent simplifies AI agent development by providing a clean, intuitive API that handles all the complexity of agent loops, tool execution, and adapter communication. Inspired by Apple's FoundationModels framework, it brings the same elegant, declarative approach to cross-platform AI agent development.

**⚠️ Work in Progress**: SwiftAgent is currently an early prototype. The basic agent loop with tool calling is already working, but there's lots of things left to implement. APIs may change, and breaking updates are expected. Use in production with caution.

## 🧭 Table of Contents

- [✨ Features](#-features)
- [🚀 Quick Start](#-quick-start)
  - [Installation](#installation)
  - [Basic Usage](#basic-usage)
  - [Building Tools](#building-tools)
  - [Structured Responses](#structured-responses)
  - [Access Transcripts](#access-transcripts)
  - [Access Token Usage](#access-token-usage)
  - [Prompt Builder](#prompt-builder)
  - [Custom Generation Options](#custom-generation-options)
- [📖 Session Schema](#-session-schema)
  - [Tools](#tools)
  - [Structured Output Entries](#structured-output-entries)
  - [Groundings](#groundings)
- [📡 Streaming Responses](#-streaming-responses)
  - [Streaming Structured Outputs](#streaming-structured-outputs)
- [🧵 Unified Streaming State Access](#-unified-streaming-state-access)
- [🌐 Proxy Servers](#-proxy-servers)
  - [Authorization](#authorization)
- [🧠 Simulated Session](#-simulated-session)
- [📝 Logging](#-logging)
- [🧪 Development Status](#-development-status)
- [📄 License](#-license)
- [🙏 Acknowledgments](#-acknowledgments)

## ✨ Features

- **🎯 Zero-Setup Agent Loops** — Handle autonomous agent execution with just a few lines of code
- **🔧 Native Tool Integration** — Use `@Generable` structs from FoundationModels as agent tools seamlessly
- **🌐 Adapter Agnostic** — Abstract interface supports multiple AI adapters (OpenAI included, more coming)
- **📱 Apple-Native Design** — API inspired by FoundationModels for familiar, intuitive development
- **🚀 Modern Swift** — Built with Swift 6, async/await, and latest concurrency features
- **📊 Rich Logging** — Comprehensive, human-readable logging for debugging and monitoring
- **🎛️ Flexible Configuration** — Fine-tune generation options, tools, and adapter settings

## 🚀 Quick Start

### Installation

Add SwiftAgent to your Swift project:

```swift
// Package.swift
dependencies: [
  .package(url: "https://github.com/SwiftedMind/SwiftAgent.git", branch: "main")
]

// OpenAI target
.product(name: "OpenAISession", package: "SwiftAgent")
```

Then import the target you need:

```swift
// For OpenAI
import OpenAISession

// Other providers coming soon
```

### Basic Usage

Create an `OpenAISession` with your default instructions and call `respond` whenever you need a single-turn answer. The session tracks conversation state for you, so you can start simple and layer on additional features later.

```swift
import OpenAISession

let session = OpenAISession(
  instructions: "You are a helpful assistant.",
  apiKey: "sk-...",
)

// Create a response
let response = try await session.respond(to: "What's the weather like in San Francisco?")

// Process response
print(response.content)
```

> Note: Using an API key directly is great for prototyping, but do not ship it in production apps. For shipping apps, use a secure proxy with per‑turn tokens. See Proxy Setup in [OpenAI Configuration](#openai-configuration).

### Building Tools

Create tools using Apple's `@Generable` macro for type-safe, schema-free tool definitions. Tools expose argument and output types that SwiftAgent validates for you, so the model can call into Swift code and receive strongly typed results without manual JSON parsing.

```swift
import FoundationModels
import OpenAISession

struct WeatherTool: Tool {
  let name = "get_weather"
  let description = "Get current weather for a location"

  @Generable
  struct Arguments {
    @Guide(description: "City name")
    let city: String

    @Guide(description: "Temperature unit")
    let unit: String
  }

  @Generable
  struct Output {
    let temperature: Double
    let condition: String
    let humidity: Int
  }

  func call(arguments: Arguments) async throws -> Output {
    return Output(
      temperature: 22.5,
      condition: "sunny",
      humidity: 65
    )
  }
}

let session = OpenAISession(
  tools: WeatherTool(),
  instructions: "You are a helpful assistant.",
  apiKey: "sk-...",
)

let response = try await session.respond(to: "What's the weather like in San Francisco?")

print(response.content)
```

> Note: Unlike Apple's `LanguageModelSession` object, `OpenAISession` takes the `tools` parameter as variadic arguments. So instead of passing an array like `tools: [WeatherTool(), OtherTool()]`, you pass the tools as a list of arguments `tools: WeatherTool(), OtherTool()`.

#### Recoverable Tool Errors

If a tool call fails in a way the agent can correct (such as an unknown identifier or other validation issue), throw a `ToolRunProblem`. SwiftAgent forwards the structured content you provide to the model without aborting the loop so the agent can adjust its next action.

SwiftAgent always wraps your payload in a standardized envelope that includes `error: true` and the `reason` string so the agent can reliably detect recoverable problems.

For quick cases, attach string-keyed details with the convenience initializer:

```swift
struct CustomerLookupTool: Tool {
  func call(arguments: Arguments) async throws -> Output {
    guard let customer = try await directory.loadCustomer(id: arguments.customerId) else {
      throw ToolRunProblem(
        reason: "Customer not found",
        details: [
          "issue": "customerNotFound",
          "customerId": arguments.customerId
        ]
      )
    }

    return Output(summary: customer.summary)
  }
}
```

For richer payloads, pass any `@Generable` type via the `content:` initializer to return structured data:

```swift
@Generable
struct CustomerLookupProblemDetails {
  var issue: String
  var customerId: String
  var suggestions: [String]
}

throw ToolRunProblem(
  reason: "Customer not found",
  content: CustomerLookupProblemDetails(
    issue: "customerNotFound",
    customerId: arguments.customerId,
    suggestions: ["Ask the user to confirm the identifier"]
  )
)
```

### Structured Responses

You can force the response to be structured by defining a type conforming to `StructuredOutput` and passing it to the `session.respond` method:

```swift
import FoundationModels
import OpenAISession

struct WeatherReport: StructuredOutput {
  static let name: String = "weatherReport"

  @Generable
  struct Schema {
    let temperature: Double
    let condition: String
    let humidity: Int
  }
}

let session = OpenAISession(
  tools: WeatherTool(),
  instructions: "You are a helpful assistant.",
  apiKey: "sk-...",
)

let response = try await session.respond(
  to: "What's the weather like in San Francisco?",
  generating: WeatherReport.self,
)

// Fully typed response content
print(response.content.temperature)
print(response.content.condition)
print(response.content.humidity)
```

The response body is now a fully typed `WeatherReport`. SwiftAgent validates the payload against your schema, so you can use the data immediately in UI or unit tests without defensive decoding.

### Access Transcripts

Every `OpenAISession` maintains a running transcript that records prompts, reasoning steps, tool calls, and responses. Iterate over it to drive custom analytics, persistence, or UI updates:

```swift
import OpenAISession

let session = OpenAISession(
  instructions: "You are a helpful assistant.",
  apiKey: "sk-...",
)

for entry in session.transcript {
  switch entry {
  case let .prompt(prompt):
    print("Prompt: ", prompt)
  case let .reasoning(reasoning):
    print("Reasoning: ", reasoning)
  case let .toolCalls(toolCalls):
    print("Tool Calls: ", toolCalls)
  case let .toolOutput(toolOutput):
    print("Tool Output: ", toolOutput)
  case let .response(response):
    print("Response: ", response)
  }
}
```

> Note: The `OpenAISession` object is `@Observable`, so you can observe its transcript for changes in real-time. This can be useful for UI applications.

### Access Token Usage

Track each session's cumulative token consumption to budget response costs or surface usage in settings screens:

```swift
import OpenAISession

let session = OpenAISession(
  instructions: "You are a helpful assistant.",
  apiKey: "sk-...",
)

print(session.tokenUsage.inputTokens)
print(session.tokenUsage.outputTokens)
print(session.tokenUsage.reasoningTokens)
print(session.tokenUsage.totalTokens)
```

> Note: Each individual response also includes token usage information. See `AgentResponse` for more details.

### Prompt Builder

Build rich prompts inline with the `@PromptBuilder` DSL. Tags group related context, keep instructions readable, and mirror the structure FoundationModels expects when you want to mix prose with metadata.

```swift
let response = try await session.respond(using: .gpt5) {
  "You are a friendly assistant who double-checks calculations."

  PromptTag("user-question") {
    "Explain how Swift's structured concurrency works."
  }

  PromptTag("formatting") {
    "Answer in three concise bullet points."
  }
}

print(response.content)
```

Under the hood SwiftAgent converts the builder result into the exact wire format required by the adapter, so you can focus on intent instead of string concatenation.

### Custom Generation Options

You can specify generation options for your responses:

```swift
import OpenAISession

let session = OpenAISession(
  instructions: "You are a helpful assistant.",
  apiKey: "sk-...",
)

let options = OpenAIGenerationOptions(
  maxOutputTokens: 1000,
  temperature: 0.7,
)

let response = try await session.respond(
  to: "What's the weather like in San Francisco?",
  using: .gpt5,
  options: options,
)

print(response.content)
```

These overrides apply only to the current turn, so you can increase creativity or token limits for specific prompts without mutating the session-wide configuration.

## 📖 Session Schema

Raw transcripts expose every event as `GeneratedContent`, which is flexible but awkward when you want to build UI or assertions.

Create a schema for your session using  `@SessionSchema` to describe the tools, groundings, and structured outputs you expect. SwiftAgent then decodes each transcript entry into strongly typed cases that mirror your declarations.

```swift
@SessionSchema
struct SessionSchema {
  @Tool var weatherTool = WeatherTool()
  @Tool var calculatorTool = CalculatorTool()

  @Grounding(Date.self) var currentDate
  @Grounding(VectorSearchResult.self) var searchResults

  @StructuredOutput(WeatherReport.self) var weatherReport
  @StructuredOutput(CalculatorOutput .self) var calculatorOutput
}

// Pass the scema to your session object
let sessionSchema = SessionSchema()
let session = OpenAISession(
  schema: sessionSchema,
  instructions: "You are a helpful assistant.",
  apiKey: "sk-...",
)
```

Each macro refines a portion of the transcript:

- `@Tool` links a tool implementation to its decoded entries, giving you typed arguments, outputs, and errors for every invocation.
- `@Grounding` registers values you inject into prompts (like dates or search results) so they can be replayed alongside the prompt text.
- `@StructuredOutput` binds a guided generation schema to its decoded result, including partial streaming updates and final values.

### Tools

Decoded tool runs combine the model's argument payload and your tool's output in one place. That makes it easy to render progress UIs and surface recoverable errors without manually joining separate transcript entries.

```swift
import FoundationModels
import OpenAISession

@SessionSchema
struct SessionSchema {
  @Tool var weatherTool = WeatherTool()
}

let sessionSchema = SessionSchema()
let session = OpenAISession(
  schema: sessionSchema,
  instructions: "You are a helpful assistant.",
  apiKey: "sk-...",
)

// let response = try await session.respond(to: "What's the weather like in San Francisco?")
// ...

for entry in try sessionSchema.decode(session.transcript) {
  switch entry {
  case let .toolRun(toolRun):
    switch toolRun {
    case let .weatherTool(weatherToolRun):
      if let arguments = weatherToolRun.finalArguments {
        print(arguments.city, arguments.city)
      }

      if let output = weatherToolRun.output {
        print(output.condition, output.humidity, output.temperature)
      }
    default:
      break
    }
  default: break
  }
}
```

### Structured Output Entries

When you request structured data, decoded responses slot those values directly into the schema you registered on the session. You can pull the result out of the live response or from the transcript later, depending on your workflow.

```swift
import FoundationModels
import OpenAISession

@SessionSchema
struct SessionSchema {
  @Tool var weatherTool = WeatherTool()
  @StructuredOutput(WeatherReport.self) var weatherReport
}

let sessionSchema = SessionSchema()
let session = OpenAISession(
  schema: sessionSchema,
  instructions: "You are a helpful assistant.",
  apiKey: "sk-...",
)

let response = try await session.respond(
  to: "What's the weather like in San Francisco?",
  generating: \.weatherReport, // or schema.weatherReport, or WeatherReport.self
)

print(response.content) // WeatherReport object

// Access the structured output in the decoded transcript
for entry in try sessionSchema.decode(session.transcript) {
  switch entry {
  case let .response(response):
    switch response.structuredSegments[0].content {
    case let .weatherReport(weatherReport):
      if let weatherReport = weatherReport.finalContent {
        print(weatherReport.condition, weatherReport.humidity, weatherReport.temperature)
      }
    case .unknown:
      print("Unknown output")
    }

  default: break
  }
}
```

### Groundings

Groundings capture extra context you feed the model—like the current time or search snippets—and keep it synchronized with the prompt text. That makes it straightforward to inspect what the model saw and to recreate prompts later for debugging.

```swift
import FoundationModels
import OpenAISession

@SessionSchema
struct SessionSchema {
  @Tool var weatherTool = WeatherTool()
  @Grounding(Date.self) var currentDate
  @StructuredOutput(WeatherReport.self) var weatherReport
}

let sessionSchema = SessionSchema()
let session = OpenAISession(
  schema: sessionSchema,
  instructions: "You are a helpful assistant.",
  apiKey: "sk-...",
)

let response = try await session.respond(
  to: "What's the weather like in San Francisco?",
  groundingWith: [.currentDate(Date())],
) { input, sources in
  PromptTag("context") {
    for source in sources {
      switch source {
      case let .currentDate(date):
        "The current date is \(date)."
      }
    }
  }

  PromptTag("user-query") {
    input
  }
}

print(response.content)

// Access the input prompt and its groundings separately in the transcript
for entry in try sessionSchema.decode(session.transcript) {
  switch entry {
  case let .prompt(prompt):
    print(prompt.input) // User input

    // Grounding sources stored alongside the input prompt
    for source in prompt.sources {
      switch source {
      case let .currentDate(date):
        print("Current date: \(date)")
      }
    }

    print(prompt.prompt) // Final prompt sent to the model
  default: break
  }
}
```

## 📡 Streaming Responses

`streamResponse` emits snapshots while the agent thinks, calls tools, and crafts the final answer. FoundationModels generates `PartiallyGenerated` companions for every `@Generable` type, turning each property into an optional so tokens can land as soon as they are decoded. SwiftAgent surfaces those partial values directly, then swaps in the fully realized type once the model finalizes the turn.

```swift
import FoundationModels
import OpenAISession

@SessionSchema
struct SessionSchema {
  @Tool var weatherTool = WeatherTool()
  @StructuredOutput(WeatherReport.self) var weatherReport
}

let session = OpenAISession(
  instructions: "You are a helpful assistant.",
  apiKey: "sk-...",
)

// Create a response
let stream = try session.streamResponse(to: "What's the weather like in San Francisco?")

for try await snapshot in stream {
  // Once the agent is sending the final response, the snapshot's content will start to populate
  if let content = snapshot.content {
    print(content)
  }

  // You can also access the generated transcript as it is streamed in
  print(snapshot.transcript)
}
```

Each snapshot contains the latest response fragment—if the model has started speaking—and the full transcript up to that point, giving you enough context to animate UI or log intermediate steps.

### Streaming Structured Outputs

Structured streaming works the same way: SwiftAgent first yields partially generated objects whose properties fill in as tokens arrive, then delivers the final schema once generation completes.

```swift
import FoundationModels
import OpenAISession

@SessionSchema
struct SessionSchema {
  @Tool var weatherTool = WeatherTool()
  @StructuredOutput(WeatherReport.self) var weatherReport
}

let sessionSchema = SessionSchema()
let session = OpenAISession(
  schema: sessionSchema,
  instructions: "You are a helpful assistant.",
  apiKey: "sk-...",
)

// Create a response
let stream = try session.streamResponse(
  to: "What's the weather like in San Francisco?",
  generating: \.weatherReport,
)

for try await snapshot in stream {
  // Once the agent is sending the final response, the snapshot's content will start to populate
  if let weatherReport = snapshot.content {
    print(weatherReport.condition ?? "Not received yet")
    print(weatherReport.humidity ?? "Not received yet")
    print(weatherReport.temperature ?? "Not received yet")
  }

  // You can also access the generated transcript as it is streamed in
  let transcript = snapshot.transcript
  let decodedTranscript = try sessionSchema.decode(transcript)

  print(transcript, decodedTranscript)
}


// You can also observe the transcript during streaming
for entry in try sessionSchema.decode(session.transcript) {
  switch entry {
  case let .response(response):
    switch response.structuredSegments[0].content {
    case let .weatherReport(weatherReport):
      switch weatherReport.content {
      case let .partial(partialWeatherReport):
        print(partialWeatherReport) // Partially populated object
      case let .final(finalWeatherReport):
        print(finalWeatherReport) // Fully populated object
      default:
        break // Not yet available
      }
    case .unknown:
      print("Unknown output")
    }

  default: break
  }
}
```

## 🧵 Unified Streaming State Access

SwiftAgent keeps SwiftUI views stable by exposing normalized projections of in-flight data. For tool runs, `normalizedArguments` always returns the partially generated variant of your argument type alongside an `isFinal` flag, so the view does not need to branch on enum states:

```swift
struct WeatherToolRunView: View {
  let run: ToolRun<WeatherTool>

  var body: some View {
    if let normalizedArguments = run.normalizedArguments {
      VStack(alignment: .leading, spacing: 4) {
        Text("City: \(normalizedArguments.city ?? "-")")
        Text("Unit: \(normalizedArguments.unit ?? "-")")

        if normalizedArguments.isFinal {
          Text("Arguments locked in").font(.caption).foregroundStyle(.secondary)
        }
      }
      .monospacedDigit()
    }
  }
}
```

Structured outputs follow the same pattern with `snapshot.normalizedContent`: you always receive a partially generated projection that updates in place, even after the final payload is available. The Example App’s Agent Playground view leans on these helpers to render incremental suggestions without triggering SwiftUI identity churn.

## 🌐 Proxy Servers

Using an API key directly is great for prototyping, but it should never be shipped to production unless you're deploying it some place you fully control. SwiftAgent comes with the option to route all agent requests through a proxy server (for example, your own backend):

```swift
let configuration = OpenAIConfiguration.proxy(through: URL(string: "https://api.your-backend.com/proxy")!)
let session = LanguageModelProvider.openAI(instructions: "...", configuration: configuration)
```

The proxy should be able to accept and handle arbitrary requests for OpenAI's Responses API. The SDK will take the proxy url you pass as the base and append the appropriate path, for example:

```bash
https://api.your-backend.com/proxy/v1/responses
```

Your backend should then take all the path segments after your proxy url and pass that to OpenAI like so:

```bash
https://api.openai.com/v1/responses
```

Optionally, your backend can intercept and decode the payload before passing it on, to verify its a legitimate request from your app and contains proper identification (like the user's id), to reduce the likelihood of abuse.

> Note: All requests that the SDK makes will fully conform to the Responses API from OpenAI.

### Authorization

It is recommended to secure that proxy endpoint via short-lived, per-turn authorization tokens that your backend issues. Before every `session.respond` or `session.streamResponse` call, you would ask your backend to generate a short-lived token. You can pass this token to the SDK by calling

Use `LanguageModelProvider.withAuthorization` to set the token for the current agent turn so every internal request (thinking steps, tool calls, final message) is authorized consistently.
- Prototyping only: `OpenAIConfiguration.direct(apiKey:)` — calls OpenAI directly and embeds an API key in the app bundle. Avoid this in production.

```swift
let token = try await backend.issueTurnToken(for: userId)
let response = try await session.withAuthorization(token: token) {
  try await session.respond(to: "Summarize yesterday's sales numbers.")
}

// Optional: automatic token refresh on 401
let initial = try await backend.issueTurnToken(for: userId)
let refreshed = try await session.withAuthorization(
  token: initial,
  refresh: { try await backend.refreshTurnToken(for: userId) }
) {
  try await session.respond(to: "Plan a team offsite agenda.")
}
```

## 🧠 Simulated Session

You can test and develop your agents without making API calls using the built-in simulation system. This is perfect for prototyping, testing, and developing UIs before integrating with live APIs.

```swift
import OpenAISession
import SimulatedSession

// Create mockable tool wrappers
struct WeatherToolMock: MockableTool {
  var tool: WeatherTool

  func mockArguments() -> WeatherTool.Arguments {
    .init(city: "San Fransico", unit: "Celsius")
  }

  func mockOutput() async throws -> WeatherTool.Output {
    .init(
      temperature: 22.5,
      condition: "sunny",
      humidity: 65
    )
  }
}

@SessionSchema
struct SessionSchema {
  @Tool var weatherTool = WeatherTool()
}

let sessionSchema = SessionSchema()
let configuration = SimulationAdapter.Configuration(defaultGenerations: [
  .reasoning(summary: "Simulated Reasoning"),
  .toolRun(tool: WeatherToolMock(tool: WeatherTool())),
  .response(text: "It's a beautiful sunny day in San Francisco with 22.5°C!"),
])

let session = SimulatedSession(
  schema: sessionSchema,
  instructions: "You are a helpful assistant.",
  configuration: configuration,
)

let response = try await session.respond(to: "What's the weather like in San Francisco?")

print(response.content) // "It's a beautiful sunny day in San Francisco with 22.5°C!"
```

## 📝 Logging

```swift
// Enable comprehensive logging
SwiftAgentConfiguration.setLoggingEnabled(true)

// Enable full request/response network logging (very verbose but helpful for debugging)
SwiftAgentConfiguration.setNetworkLoggingEnabled(true)

// Logs show:
// 🟢 Agent start — model=gpt-5 | tools=weather, calculator
// 🛠️ Tool call — weather [abc123]
// 📤 Tool output — weather [abc123]
// ✅ Finished
```

## 🧪 Development Status

**⚠️ Work in Progress**: SwiftAgent is under active development. APIs may change, and breaking updates are expected. Use in production with caution.

## 📄 License

SwiftAgent is available under the MIT license. See [LICENSE](LICENSE) for more information.

## 🙏 Acknowledgments

- Inspired by Apple's [FoundationModels](https://developer.apple.com/documentation/foundationmodels) framework
- Built with the amazing Swift ecosystem and community

*Made with ❤️ for the Swift community*

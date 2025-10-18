[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FSwiftedMind%2FSwiftAgent%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/SwiftedMind/SwiftAgent)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FSwiftedMind%2FSwiftAgent%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/SwiftedMind/SwiftAgent)

# SwiftAgent

**Native Swift SDK for building autonomous AI agents with Apple's FoundationModels design philosophy**

SwiftAgent simplifies AI agent development by providing a clean, intuitive API that handles all the complexity of agent loops, tool execution, and adapter communication. Inspired by Apple's FoundationModels framework, it brings the same elegant, declarative approach to cross-platform AI agent development.

**⚠️ Work in Progress**: SwiftAgent is currently an early prototype. The basic agent loop with tool calling is already working, but there's lots of things left to implement. APIs may change, and breaking updates are expected. Use in production with caution.

## Table of Contents

- [✨ Features](#-features)
- [🚀 Quick Start](#-quick-start)
  - [Installation](#installation)
  - [Basic Usage](#basic-usage)
- [🛠️ Building Tools](#️-building-tools)
- [📖 Advanced Usage](#-advanced-usage)
  - [Prompt Context](#prompt-context)
  - [Tool Decoder](#tool-decoder)
  - [Structured Output Generation](#structured-output-generation)
  - [Custom Generation Options](#custom-generation-options)
  - [Conversation History](#conversation-history)
  - [Simulated Session](#simulated-session)
- [🔧 Configuration](#-configuration)
  - [OpenAI Configuration](#openai-configuration)
  - [Logging](#logging)
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

## Basic Usage

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

### 🛠️ Building Tools

Create tools using Apple's `@Generable` macro for type-safe, schema-free tool definitions:

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

### Structured Outputs

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

### Access Tanscripts

Access the session's transcript to retrieve and process the conversation history:

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

Access the session's accumulated token usage:

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

TODO Explanations and examples for the prompt builder result builder

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

## 📖 Session Schema

The transcript object for the `OpenAISession` contains a lot of generated content packed inside of `GeneratedContent` objects, which are essentially wrappers around JSON objects, making them fairly inconvenient to work with. To solve this, SwiftAgent comes with a mechanism that can decode the transcript into a new object that contains _fully typped_ entries for all your tool calls, structured outputs and more.

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
```

// TODO: Explain @Tool @Grounding and @StructuredOutput and what a tool run is etc.

### Tools

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

### Structured Outputs

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

## Streaming Responses

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

### Structured Outputs

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


TODO: Streaming

TODO: "Best Practices"
-> "normalized" concept for UI

TODO: Example App walkthrough

TODO: Proxy Servers















### Simulated Session

Test and develop your agents without making API calls using the built-in simulation system. Perfect for prototyping, testing, and developing UIs before integrating with live APIs.

```swift
import OpenAISession
import SimulatedSession

// Create mockable tool wrappers
struct WeatherToolMock: MockableTool {
  var tool: WeatherTool

  func mockArguments() -> WeatherTool.Arguments {
    .init(location: "San Francisco")
  }

  func mockOutput() async throws -> WeatherTool.Output {
    .init(
      location: "San Francisco",
      temperature: 22.5,
      condition: "sunny",
      humidity: 65
    )
  }
}

// Use simulateResponse instead of respond
let response = try await session.simulateResponse(
  to: "What's the weather like in San Francisco?",
  generations: [
    .toolRun(tool: WeatherToolMock(tool: WeatherTool())),
    .response(content: "It's a beautiful sunny day in San Francisco with 22.5°C!")
  ]
)

print(response.content) // "It's a beautiful sunny day in San Francisco with 22.5°C!"
```

The simulation system provides:
- **Zero API costs** during development and testing
- **Predictable responses** for consistent UI testing
- **Tool execution simulation** with mock data
- **Complete transcript compatibility** - simulated responses work exactly like real ones
- **Structured output support** - any `@Generable` struct used with `simulateResponse(generating:)` must conform to `MockableGenerable` for mock generation

## 🔧 Configuration

### OpenAI Configuration

- Recommended: `OpenAIConfiguration.proxy(through:)` — route all requests through your own backend. Your backend issues short‑lived, per‑turn tokens. Use `LanguageModelProvider.withAuthorization` to set the token for the current agent turn so every internal request (thinking steps, tool calls, final message) is authorized consistently.
- Prototyping only: `OpenAIConfiguration.direct(apiKey:)` — calls OpenAI directly and embeds an API key in the app bundle. Avoid this in production.

```swift
// Proxy configuration (recommended)
let configuration = OpenAIConfiguration.proxy(through: URL(string: "https://api.your-backend.com")!)
let session = LanguageModelProvider.openAI(tools: tools, instructions: "...", configuration: configuration)

// Per‑turn authorization
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

### Logging

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

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
  - [Alternative Configuration Methods](#alternative-configuration-methods)
- [🛠️ Building Tools](#️-building-tools)
- [📖 Advanced Usage](#-advanced-usage)
  - [Prompt Context](#prompt-context)
  - [Tool Resolver](#tool-resolver)
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

### Basic Usage

```swift
import OpenAISession

// Create an OpenAI session
let session = ModelSession.openAI(
  tools: [WeatherTool(), CalculatorTool()],
  instructions: "You are a helpful assistant.",
  apiKey: "sk-...",
)

// Run your agent
let response = try await session.respond(to: "What's the weather like in San Francisco?")

// Process response
print(response.content)
```

> Note: Using an API key directly is great for prototyping, but do not ship it in production apps. For shipping apps, use a secure proxy with per‑turn tokens. See Proxy Setup in [OpenAI Configuration](#openai-configuration).

#### Alternative Configuration Methods

```swift
// Using custom configuration
let configuration = OpenAIConfiguration.direct(apiKey: "your-api-key")
let session = ModelSession.openAI(tools: tools, instructions: "...", configuration: configuration)
```

## 🛠️ Building Tools

Create tools using Apple's `@Generable` macro for type-safe, schema-free tool definitions:

```swift
struct WeatherTool: SwiftAgentTool {
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
    // Your weather API implementation
    return Output(
      temperature: 22.5,
      condition: "sunny",
      humidity: 65
    )
  }
}
```

### Handling Recoverable Tool Errors

If a tool call fails in a way the agent can correct (such as an unknown identifier or other validation issue), throw a `ToolRunProblem`. SwiftAgent forwards the structured content you provide to the model without aborting the loop so the agent can adjust its next action.

SwiftAgent always wraps your payload in a standardized envelope that includes `error: true` and the `reason` string so the agent can reliably detect recoverable problems.

For quick cases, attach string-keyed details with the convenience initializer:

```swift
struct CustomerLookupTool: SwiftAgentTool {
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

## 📖 Advanced Usage

### Prompt Context

Separate user input from contextual information for cleaner prompt augmentation and better transcript organization:

```swift
import OpenAISession

// Define your context types
enum ContextSource: PromptContextSource, PromptRepresentable {
  case vectorSearchResult(String)
  case documentContext(String)
  case searchResults([String])
  
  @PromptBuilder
  var promptRepresentation: Prompt {
    switch self {
    case .vectorSearchResult(let content):
      PromptTag("vector-embedding") { content }
    case .documentContext(let content):
      PromptTag("document") { content }
    case .searchResults(let results):
      PromptTag("search-results") {
        for result in results {
          result
        }
      }
    }
  }
}

// Create a session with context support and pass a context source
let session = ModelSession.openAI(tools: tools, context: ContextSource.self, apiKey: "sk-...")

// Respond with context - user input and context are kept separated in the transcript
let response = try await session.respond(
  to: "What are the key features of SwiftUI?",
  supplying: [
    .vectorSearchResult("SwiftUI declarative syntax..."),
    .documentContext("Apple's official SwiftUI documentation...")
  ]
) { input, context in
  PromptTag("context", items: context.sources)
  input
}

// The transcript now clearly separates user input from augmented context
for entry in session.transcript {
  if case let .prompt(prompt) = entry {
    print("User input: \(prompt.input)")
    print("Context sources: \(prompt.context.sources.count)")
  }
}
```

### Tool Resolver

`Transcript.Resolved` rebuilds the transcript you already consume, but replaces each
`.toolCalls` and `.toolOutput` pair with a `.toolRun` that carries your typed resolution. You still
walk the transcript the same way, now with a single case per tool.

```swift
// Enumerate all tools you want to handle in the UI
enum ToolRunKind {
  case weather(ToolRun<WeatherTool>)
  case calculator(ToolRun<CalculatorTool>)
}

extension WeatherTool {
  // Map the raw run into your enum case
  func resolve(_ run: ToolRun<WeatherTool>) -> ToolRunKind {
    .weather(run)
  }
}

let tools: [any SwiftAgentTool<ToolRunKind>] = [WeatherTool(), CalculatorTool()]
let configuration = OpenAIConfiguration.direct(apiKey: "sk-...")
let session = ModelSession.openAI(tools: tools, instructions: "...", configuration: configuration)

if let resolvedTranscript = session.transcript.resolved(using: tools) {
  for entry in resolvedTranscript {
    switch entry {
    case let .toolRun(toolRun):
      // React to the merged tool run
      switch toolRun.resolution {
      case let .weather(run):
        print("Weather loaded for \(run.arguments.city)")
      case let .calculator(run):
        print("Calculator finished: \(run.arguments.expression)")
      }
    default:
      break
    }
  }
}
```

The resolved transcript rebuilds itself from `Transcript`, so create it when you need to render
tool runs and discard it afterward.

#### Tool Resolver Instances

Prefer a reusable resolver object when you want to resolve individual tool calls on demand.

```swift
enum ToolRunKind {
  case weather(ToolRun<WeatherTool>)
  case calculator(ToolRun<CalculatorTool>)
}

extension WeatherTool {
  func resolve(_ run: ToolRun<WeatherTool>) -> ToolRunKind {
    .weather(run)
  }
}

let tools: [any SwiftAgentTool<ToolRunKind>] = [WeatherTool(), CalculatorTool()]
let configuration = OpenAIConfiguration.direct(apiKey: "sk-...")
let session = ModelSession.openAI(tools: tools, instructions: "...", configuration: configuration)

let toolResolver = session.transcript.toolResolver(using: tools)

for entry in session.transcript {
  if case let .toolCalls(toolCalls) = entry {
    for toolCall in toolCalls {
      let resolvedTool = try toolResolver.resolve(toolCall)

      switch resolvedTool {
      case let .weather(run):
        print("Weather for: \(run.arguments.city)")
        if let output = run.output {
          print("Temperature: \(output.temperature)°")
        }
      case let .calculator(run):
        print("Calculation: \(run.arguments.expression)")
        if let output = run.output {
          print("Result: \(output.result)")
        }
      }
    }
  }
}
```

### Structured Output Generation

Generate structured data directly from agent responses:

```swift
@Generable
struct TaskList {
  let tasks: [Task]
  let priority: String
}

@Generable 
struct Task {
  let title: String
  let completed: Bool
}

let response = try await session.respond(
  to: "Create a todo list for planning a vacation",
  generating: TaskList.self
)

// response.content is now a strongly-typed TaskList
for task in response.content.tasks {
  print("- \(task.title)")
}
```

### Custom Generation Options

Specify generation options for your responses:

```swift
let options = OpenAIGenerationOptions(
  maxOutputTokens: 1000,
  temperature: 0.7
)

let response = try await session.respond(
  to: "Help me analyze this data",
  using: .gpt5,
  options: options
)
```

### Conversation History

Access full conversation transcripts:

```swift
// Continue conversations naturally
try await session.respond(to: "What was my first question?")

// Access conversation history
for entry in session.transcript {
  switch entry {
  case .prompt(let prompt):
    print("User: \(prompt.input)")
  case .response(let response):
    print("Agent: \(response.content)")
  case .toolCalls(let calls):
    print("Tool calls: \(calls.calls.map(\.toolName))")
  // ... handle other entry types
  }
}
```

### Simulated Session

Test and develop your agents without making API calls using the built-in simulation system. Perfect for prototyping, testing, and developing UIs before integrating with live APIs.

```swift
import OpenAISession
import SimulatedSession

// Create mockable tool wrappers
struct WeatherToolMock: MockableAgentTool {
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

- Recommended: `OpenAIConfiguration.proxy(through:)` — route all requests through your own backend. Your backend issues short‑lived, per‑turn tokens. Use `ModelSession.withAuthorization` to set the token for the current agent turn so every internal request (thinking steps, tool calls, final message) is authorized consistently.
- Prototyping only: `OpenAIConfiguration.direct(apiKey:)` — calls OpenAI directly and embeds an API key in the app bundle. Avoid this in production.

```swift
// Proxy configuration (recommended)
let configuration = OpenAIConfiguration.proxy(through: URL(string: "https://api.your-backend.com")!)
let session = ModelSession.openAI(tools: tools, instructions: "...", configuration: configuration)

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

// Enable full request/response network logging
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

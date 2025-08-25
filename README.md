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

#### Alternative Configuration Methods

```swift
// Using custom configuration
let configuration = OpenAIConfiguration.direct(apiKey: "your-api-key")
let session = ModelSession.openAI(tools: tools, instructions: "...", configuration: configuration)
```

## 🛠️ Building Tools

Create tools using Apple's `@Generable` macro for type-safe, schema-free tool definitions:

```swift
struct WeatherTool: AgentTool {
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

Get type-safe access to tool runs in your UI code by combining tool calls with their outputs:

```swift
// Define a resolved tool run enum for type-safe tool grouping
enum ResolvedToolRun {
  case weather(AgentToolRun<WeatherTool>)
  case calculator(AgentToolRun<CalculatorTool>)
}

// Implement the resolve method in your tools
extension WeatherTool {
  func resolve(_ run: AgentToolRun<WeatherTool>) -> ResolvedToolRun {
    .weather(run)
  }
}

// Use the tool resolver to get compile-time safe tool access
let tools: [any AgentTool<ResolvedToolRun>] = [WeatherTool(), CalculatorTool()]
let configuration = OpenAIConfiguration.direct(apiKey: "sk-...")
let session = ModelSession.openAI(tools: tools, instructions: "...", configuration: configuration)

// After the agent runs, resolve tool calls for UI display
let toolResolver = session.transcript.toolResolver(for: tools)

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

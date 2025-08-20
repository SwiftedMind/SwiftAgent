[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FSwiftedMind%2FSwiftAgent%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/SwiftedMind/SwiftAgent)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FSwiftedMind%2FSwiftAgent%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/SwiftedMind/SwiftAgent)

# SwiftAgent

**Native Swift SDK for building autonomous AI agents with Apple's FoundationModels design philosophy**

SwiftAgent simplifies AI agent development by providing a clean, intuitive API that handles all the complexity of agent loops, tool execution, and adapter communication. Inspired by Apple's FoundationModels framework, it brings the same elegant, declarative approach to cross-platform AI agent development.

**⚠️ Work in Progress**: SwiftAgent is currently an early prototype. The basic agent loop with tool calling is already working, but there's lots of things left to implement. APIs may change, and breaking updates are expected. Use in production with caution.

## Table of Contents

TODO: Fix

---

## ✨ Features

- **🎯 Zero-Setup Agent Loops** — Handle autonomous agent execution with just a few lines of code
- **🔧 Native Tool Integration** — Use `@Generable` structs from FoundationModels as agent tools seamlessly  
- **🌐 Adapter Agnostic** — Abstract interface supports multiple AI adapters (OpenAI included, more coming)
- **📱 Apple-Native Design** — API inspired by FoundationModels for familiar, intuitive development
- **🚀 Modern Swift** — Built with Swift 6, async/await, and latest concurrency features
- **📊 Rich Logging** — Comprehensive, human-readable logging for debugging and monitoring
- **🎛️ Flexible Configuration** — Fine-tune generation options, tools, and adapter settings

---

## 🚀 Quick Start

### Installation

Add SwiftAgent to your Swift project:

```swift
// Package.swift
dependencies: [
  .package(url: "https://github.com/SwiftedMind/SwiftAgent.git", branch: "main")
]
```

Then import the provider module you need:

```swift
// For OpenAI
import OpenAIAgent

// Core framework (for custom adapters)
import SwiftAgent
```

### Basic Usage

```swift
import OpenAIAgent
import FoundationModels

// Create an agent with OpenAI - multiple configuration options available
let agent = OpenAIAgent(
  tools: [WeatherTool(), CalculatorTool()],
  instructions: "You are a helpful assistant."
)

// Run your agent
let response = try await agent.respond(
  to: "What's the weather like in San Francisco?",
  using: .gpt5
)

print(response.content)
```

#### Alternative Configuration Methods

```swift
// Using default configuration (requires environment setup)
let agent = OpenAIAgent(tools: tools, instructions: "...")

// Using custom configuration
let config = OpenAIAdapter.Configuration.direct(apiKey: "your-api-key")
let agent = OpenAIAgent(tools: tools, instructions: "...", configuration: config)
```

---

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
    
    @Guide(description: "Temperature unit", .oneOf(["celsius", "fahrenheit"]))
    let unit: String = "celsius"
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

---

## 📖 Advanced Usage

### Prompt Context

Separate user input from contextual information for cleaner prompt augmentation and better transcript organization:

```swift
import OpenAIAgent

// Define your context types
enum PromptContext: SwiftAgent.PromptContext, SwiftAgent.PromptRepresentable {
  case vectorEmbedding(String)
  case documentContext(String)
  case searchResults([String])
  
  @PromptBuilder
  var promptRepresentation: Prompt {
    switch self {
    case .vectorEmbedding(let content):
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

// Create an agent that supports context
let agent: Agent<OpenAIAdapter, PromptContext> = Agent(
  adapter: OpenAIAdapter(tools: tools, instructions: "...", configuration: config)
)

// Respond with context - user input and context are separated in the transcript
let response = try await agent.respond(
  to: "What are the key features of SwiftUI?",
  supplying: [
    .vectorEmbedding("SwiftUI declarative syntax..."),
    .documentContext("Apple's official SwiftUI documentation...")
  ]
) { input, context in
  PromptTag("context", items: context)
  input
}

// The transcript now clearly separates user input from augmented context
for entry in agent.transcript {
  if case let .prompt(prompt) = entry {
    print("User input: \(prompt.content)")
    print("Context items: \(prompt.context.count)")
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
let agent = OpenAIAgent(tools: tools, instructions: "...")

// After the agent runs, resolve tool calls for UI display
let toolResolver = agent.transcript.toolResolver(for: tools)

for entry in agent.transcript {
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

### Convenience Initializers

OpenAIAgent provides streamlined initializers:

```swift
// Most convenient - direct API key
let agent = OpenAIAgent(
  tools: tools, 
  instructions: "...",
  apiKey: "your-api-key"
)

// Using configuration object  
let agent = OpenAIAgent(
  tools: tools,
  instructions: "...",
  configuration: config
)

// Basic usage with default configuration
let agent = OpenAIAgent(tools: tools, instructions: "...")

// Generic form for custom adapters (requires SwiftAgent import)
import SwiftAgent
let agent = Agent(adapter: CustomAdapter(...))
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

let response = try await agent.respond(
  to: "Create a todo list for planning a vacation",
  generating: TaskList.self,
  using: .gpt5
)

// response.content is now a strongly-typed TaskList
for task in response.content.tasks {
  print("- \(task.title)")
}
```

### Custom Generation Options

```swift
let options = GenerationOptions(
  maxTokens: 1000,
  temperature: 0.7,
  allowedSteps: 10
)

let response = try await agent.respond(
  to: "Help me analyze this data",
  using: .gpt5,
  options: options
)
```

### Conversation History

Access full conversation transcripts:

```swift
// Continue conversations naturally
try await agent.respond(to: "What was my first question?")

// Access conversation history
for entry in agent.transcript {
  switch entry {
  case .prompt(let prompt):
    print("User: \(prompt.content)")
  case .response(let response):
    print("Agent: \(response.content)")
  case .toolCalls(let calls):
    print("Tool calls: \(calls.calls.map(\.toolName))")
  // ... handle other entry types
  }
}
```

### Agent Simulation

Test and develop your agents without making API calls using the built-in simulation system. Perfect for prototyping, testing, and developing UIs before integrating with live APIs.

```swift
import OpenAIAgent
import AgentSimulation

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
let response = try await agent.simulateResponse(
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

---

## 🔧 Configuration

### OpenAI Configuration

```swift
import OpenAIAgent

// Method 1: Direct API key in initializer (recommended)
let agent = OpenAIAgent(
  tools: tools,
  instructions: "...",
  apiKey: "sk-..."
)

// Method 2: Configuration object
let config = OpenAIAdapter.Configuration.direct(
  apiKey: "sk-...",
  baseURL: URL(string: "https://api.openai.com")!
)
let agent = OpenAIAgent(tools: tools, instructions: "...", configuration: config)

// Method 3: Global default configuration
OpenAIAdapter.Configuration.setDefaultConfiguration(config)
let agent = OpenAIAgent(tools: tools, instructions: "...")
```

### Custom Adapters

Create your own AI provider adapters:

```swift
import SwiftAgent

// Implement the AgentAdapter protocol
struct GeminiAdapter: AgentAdapter {
  // Implementation details...
}

// Use with the core Agent class
let agent = Agent(adapter: GeminiAdapter(...))
```

### Logging

```swift
// Enable comprehensive logging
AgentConfiguration.setLoggingEnabled(true)

// Logs show:
// 🟢 Agent start — model=gpt-5 | tools=weather, calculator
// 🛠️ Tool call — weather [abc123]
// 📤 Tool output — weather [abc123]
// ✅ Finished
```

---

## 🧪 Development Status

**⚠️ Work in Progress**: SwiftAgent is under active development. APIs may change, and breaking updates are expected. Use in production with caution.

---

## 📄 License

SwiftAgent is available under the MIT license. See [LICENSE](LICENSE) for more information.

---

## 🙏 Acknowledgments

- Inspired by Apple's [FoundationModels](https://developer.apple.com/documentation/foundationmodels) framework
- Built with the amazing Swift ecosystem and community

---

*Made with ❤️ for the Swift community*

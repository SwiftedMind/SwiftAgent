// By Dennis Müller

import Foundation
import FoundationModels
import Observation
import OpenAISession

@MainActor
enum ReadmeExamples {
  @SessionSchema
  struct SessionSchema {
    @Tool var weatherTool = WeatherTool()
    @Grounding(Date.self) var currentDate
    @StructuredOutput(WeatherReport.self) var weatherReport
  }

  /// Step: Basic Usage
  func basicUsage() async throws {
    // Create a new instance of the session
    let session = OpenAISession(
      instructions: "You are a helpful assistant.",
      apiKey: "sk-...",
    )

    // Create a response
    let response = try await session.respond(to: "What's the weather like in San Francisco?")

    // Process response
    print(response.content)
  }

  /// Step: Building Tools
  func basicUsage_buildingTools() async throws {
    // Create a new instance of the session
    let session = OpenAISession(
      tools: WeatherTool(),
      instructions: "You are a helpful assistant.",
      apiKey: "sk-...",
    )

    // Create a response
    let response = try await session.respond(to: "What's the weather like in San Francisco?")

    // Process response
    print(response.content)
  }

  func basicUsage_structuredOutputs() async throws {
    let session = OpenAISession(
      schema: SessionSchema(),
      instructions: "You are a helpful assistant.",
      apiKey: "sk-...",
    )

    let response = try await session.respond(
      to: "What's the weather like in San Francisco?",
      generating: WeatherReport.self,
    )

    print(response.content.temperature)
    print(response.content.condition)
    print(response.content.humidity)
  }

  func basicUsage_accessTranscripts() async throws {
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
  }

  func basicUsage_accessTokenUsage() async throws {
    let session = OpenAISession(
      instructions: "You are a helpful assistant.",
      apiKey: "sk-...",
    )

    print(session.tokenUsage.inputTokens ?? 0)
    print(session.tokenUsage.outputTokens ?? 0)
    print(session.tokenUsage.reasoningTokens ?? 0)
    print(session.tokenUsage.totalTokens ?? 0)
  }

  func sessionSchema_tools() async throws {
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
  }

  func sessionSchema_structuredOutputs() async throws {
    let sessionSchema = SessionSchema()
    let session = OpenAISession(
      schema: sessionSchema,
      instructions: "You are a helpful assistant.",
      apiKey: "sk-...",
    )

    let response = try await session.respond(
      to: "What's the weather like in San Francisco?",
      generating: \.weatherReport,
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
  }

  func sessionSchema_groundings() async throws {
    let sessionSchema = SessionSchema()
    let session = OpenAISession(
      schema: sessionSchema,
      instructions: "You are a helpful assistant.",
      apiKey: "sk-...",
    )

    // Create a response
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
  }

  func something() async throws {
    let schema = SessionSchema()
    let session = OpenAISession(schema: schema, instructions: "", apiKey: "")
    let response = try await session.respond(to: "String", generating: \.weatherReport)
    let response2 = try await session.respond(to: "String", generating: schema.weatherReport)
    let response3 = try await session.respond(
      to: "String",
      generating: \.weatherReport,
      groundingWith: [.currentDate(Date())],
    ) { input, sources in
      "String"
    }
    print(response.content.generatedContent)
    print(response2.content.generatedContent)
    print(response3.content.generatedContent)

    _ = try session.streamResponse(to: "String", generating: \.weatherReport)
    _ = try session.streamResponse(to: "String", generating: schema.weatherReport)
    _ = try session.streamResponse(
      to: "String",
      generating: \.weatherReport,
      groundingWith: [.currentDate(Date())],
    ) { input, sources in
      "String"
    }
  }
}

extension ReadmeExamples {
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
      // Your weather API implementation
      Output(
        temperature: 22.5,
        condition: "sunny",
        humidity: 65,
      )
    }
  }

  struct WeatherReport: StructuredOutput {
    static let name: String = "weatherReport"

    @Generable
    struct Schema {
      let temperature: Double
      let condition: String
      let humidity: Int
    }
  }
}

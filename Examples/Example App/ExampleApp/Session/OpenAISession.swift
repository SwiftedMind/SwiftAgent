// By Dennis Müller

import Foundation
import FoundationModels
import Observation
import OpenAISession

@SessionSchema
struct SessionSchema {
  @Tool var calculator = CalculatorTool()
  @Tool var weather = WeatherTool()
  @Grounding(Date.self) var currentDate
  @StructuredOutput(WeatherReport.self) var weatherReport
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

struct CalculatorTool: Tool {
  let name = "calculator"
  let description = "Performs basic mathematical calculations"

  @Generable
  struct Arguments {
    @Guide(description: "The first number")
    let firstNumber: Double

    @Guide(description: "The operation to perform (+, -, *, /)")
    let operation: String

    @Guide(description: "The second number")
    let secondNumber: Double
  }

  @Generable
  struct Output {
    let result: Double
  }

  func call(arguments: Arguments) async throws -> Output {
    let result: Double

    switch arguments.operation {
    case "+":
      result = arguments.firstNumber + arguments.secondNumber
    case "-":
      result = arguments.firstNumber - arguments.secondNumber
    case "*":
      result = arguments.firstNumber * arguments.secondNumber
    case "/":
      guard arguments.secondNumber != 0 else {
        throw ToolError.divisionByZero
      }

      result = arguments.firstNumber / arguments.secondNumber
    default:
      throw ToolError.unsupportedOperation(arguments.operation)
    }

    return Output(result: result)
  }
}

struct WeatherTool: Tool {
  let name = "get_weather"
  let description = "Provides a simple weather forecast for a specific place and time"

  @Generable
  struct Arguments {
    @Guide(description: "The city or location to get weather for")
    let location: String

    @Guide(description: "The calendar date to request the forecast for (e.g., 2024-04-01)")
    let requestedDate: String

    @Guide(description: "The time of day for the forecast (morning, afternoon, evening)")
    let timeOfDay: String
  }

  @Generable
  struct Output {
    let location: String
    let temperature: Int
    let condition: String
    let humidity: Int
  }

  func call(arguments: Arguments) async throws -> Output {
    // Simulate API delay
    try await Task.sleep(nanoseconds: 500_000_000)

    // Mock weather data based on location
    let mockWeatherData: [String: (String, Int, String, Int)] = [
      "london": ("London", 15, "Cloudy", 78),
      "paris": ("Paris", 18, "Sunny", 65),
      "tokyo": ("Tokyo", 22, "Rainy", 85),
      "new york": ("New York", 20, "Partly Cloudy", 72),
      "sydney": ("Sydney", 25, "Sunny", 55),
    ]

    let locationKey = arguments.location.lowercased()
    let baseWeatherData = mockWeatherData[locationKey] ??
      (
        arguments.location,
        Int.random(in: 10...30),
        ["Sunny", "Cloudy", "Rainy"].randomElement()!,
        Int.random(in: 40...90)
      )

    let normalizedTimeOfDay = arguments.timeOfDay.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let timeLabel: String = switch normalizedTimeOfDay {
    case "morning":
      "Morning"
    case "afternoon":
      "Afternoon"
    case "evening":
      "Evening"
    default:
      arguments.timeOfDay.capitalized
    }

    let conditionDescription = "\(baseWeatherData.2) - \(timeLabel) forecast for \(arguments.requestedDate)"

    return Output(
      location: baseWeatherData.0,
      temperature: baseWeatherData.1,
      condition: conditionDescription,
      humidity: baseWeatherData.3,
    )
  }
}

enum ToolError: Error, LocalizedError {
  case divisionByZero
  case unsupportedOperation(String)

  var errorDescription: String? {
    switch self {
    case .divisionByZero:
      "Cannot divide by zero"
    case let .unsupportedOperation(operation):
      "Unsupported operation: \(operation)"
    }
  }
}

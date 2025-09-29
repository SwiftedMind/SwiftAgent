// By Dennis Müller

import FoundationModels
import OpenAISession
import SwiftUI

/*

 TODOS:
 - Example: A text label (with the input, fixed, not a text field) and a button "Generate" -> Then UI streams in the response
 - Update the example app to be more flexible for future use cases; make its entry a list screen that leads to the individual examples
 - Think about transcript resolution and if you could simplify the other cases as well
 - Go through the OpenAIAdapter streaming logic and see if you can simplify it or at least make it more readable and check for correctness
 - In AgentSnapshot, add a method "collect()" that turns the snapshot into a response, like in FoundationModels
 - In AgentSnapshot, add logic to populate the output content (final response from the transcript) after the stream is finished
 - Go through the entire "streaming flow" to check if it's fine and nicely useable.

 */

@main
struct ExampleApp: App {
	init() {
		// Enable logging for development
		SwiftAgentConfiguration.setLoggingEnabled(true)
		SwiftAgentConfiguration.setNetworkLoggingEnabled(true)
	}

	var body: some Scene {
		WindowGroup {
			ExampleListView()
				.task {
					do {
						let transcript = try await test()
						print(transcript)
						print(transcript.partiallyResolved(using: Tools.all)!)
					} catch {
						print("Unexpected error: \(error).")
					}
				}
		}
	}
}

// MARK: - Prompt Context

enum ContextSource: PromptContextSource {
	case currentDate(Date)
}

// MARK: - Tools

#tools {
	CalculatorTool()
	WeatherTool()
}

struct CalculatorTool: SwiftAgentTool {
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
		let expression: String
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

		let expression = "\(arguments.firstNumber) \(arguments.operation) \(arguments.secondNumber) = \(result)"
		return Output(result: result, expression: expression)
	}
}

struct WeatherTool: SwiftAgentTool {
	let name = "get_weather"
	let description = "Gets current weather information for a location"

	@Generable
	struct Arguments: Encodable {
		@Guide(description: "The city or location to get weather for")
		let location: String
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
		let mockWeatherData = [
			"london": ("London", 15, "Cloudy", 78),
			"paris": ("Paris", 18, "Sunny", 65),
			"tokyo": ("Tokyo", 22, "Rainy", 85),
			"new york": ("New York", 20, "Partly Cloudy", 72),
			"sydney": ("Sydney", 25, "Sunny", 55),
		]

		let locationKey = arguments.location.lowercased()
		let weatherData = mockWeatherData[locationKey] ??
			(
				arguments.location,
				Int.random(in: 10...30),
				["Sunny", "Cloudy", "Rainy"].randomElement()!,
				Int.random(in: 40...90)
			)

		return Output(
			location: weatherData.0,
			temperature: weatherData.1,
			condition: weatherData.2,
			humidity: weatherData.3,
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

// By Dennis Müller

import Foundation
import FoundationModels
import SwiftAgent

@Resolvable
struct ToolGroup {
	static let contextSource = ContextSource.self
	@ResolvableTool var calculator = CalculatorTool()
	@ResolvableTool var weather = WeatherTool()
}

struct CalculatorTool: Tool, SwiftAgentTool {
	let name = "calculator"
	let description = "Performs basic mathematical calculations"
	
	@Generable
	struct Arguments: Equatable {
		@Guide(description: "The first number")
		let firstNumber: Double
		
		@Guide(description: "The operation to perform (+, -, *, /)")
		let operation: String
		
		@Guide(description: "The second number")
		let secondNumber: Double
	}
	
	@Generable
	struct Output: Equatable {
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

struct WeatherTool: Tool, SwiftAgentTool {
	let name = "get_weather"
	let description = "Gets current weather information for a location"
	
	@Generable
	struct Arguments: Equatable {
		@Guide(description: "The city or location to get weather for")
		let location: String
	}
	
	@Generable
	struct Output: Equatable {
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

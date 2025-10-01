// By Dennis Müller

import Foundation
import FoundationModels
import OpenAISession

// TODO: Fix Grounding enum ergonomics
// TODO: Implement Grounding decoding in Transcript resolution
// TODO: Maybe a @SwiftAgentTool macro that adds Equatable conformance to Generable types?

@SwiftAgentSession(provider: .openAI) @Observable
final class OpenAISession {
	@ResolvableTool let calculator = CalculatorTool()
	@ResolvableTool let weather = WeatherTool()
}

func test() {
	// let session = OpenAISession(instructions: "", apiKey: "")
}

// @Observable
// final class OpenAISession: ModelSession {
//	let calculator: CalculatorTool
//
//	enum Grounding: GroundingRepresentable {
//		case vectorSearch(String)
//		case linkPreview(URL)
//	}
//
//	enum ResolvedToolRun: Equatable {
//		case calculator(ToolRun<ResolvableCalculatorTool>)
//	}
//
//	enum PartiallyResolvedToolRun: Equatable {
//		case calculator(PartialToolRun<ResolvableCalculatorTool>)
//	}
//
//	typealias Adapter = OpenAIAdapter
//	typealias SessionType = OpenAISession
//
//	var adapter: OpenAIAdapter
//	var transcript: SwiftAgent.Transcript
//	var tokenUsage: TokenUsage
//	nonisolated let tools: [any ResolvableTool<OpenAISession>]
//
//	init(
//		calculator: CalculatorTool,
//		instructions: String,
//		apiKey: String,
//	) {
//		let tools = [
//			ResolvableCalculatorTool(baseTool: calculator)
//		]
//
//		self.calculator = calculator
//		self.tools = tools
//
//		adapter = OpenAIAdapter(
//			tools: tools,
//			instructions: instructions,
//			configuration: .direct(apiKey: apiKey)
//		)
//		transcript = Transcript()
//		tokenUsage = TokenUsage()
//	}
//
//	init(
//		calculator: CalculatorTool,
//		instructions: String,
//		configuration: OpenAIConfiguration,
//	) {
//		let tools = [
//			ResolvableCalculatorTool(baseTool: calculator)
//		]
//
//		self.calculator = calculator
//		self.tools = tools
//
//		adapter = OpenAIAdapter(
//			tools: tools,
//			instructions: instructions,
//			configuration: configuration
//		)
//		transcript = Transcript()
//		tokenUsage = TokenUsage()
//	}
//
//	struct ResolvableCalculatorTool: ResolvableTool {
//		typealias Session = SessionType
//		typealias BaseTool = CalculatorTool
//		typealias Arguments = BaseTool.Arguments
//		typealias Output = BaseTool.Output
//
//		private let baseTool: BaseTool
//
//		init(baseTool: CalculatorTool) {
//			self.baseTool = baseTool
//		}
//
//		var name: String {
//			baseTool.name
//		}
//
//		var description: String {
//			baseTool.description
//		}
//
//		var parameters: GenerationSchema {
//			baseTool.parameters
//		}
//
//		func call(arguments: Arguments) async throws -> Output {
//			try await baseTool.call(arguments: arguments)
//		}
//
//		func resolve(
//			_ run: ToolRun<ResolvableCalculatorTool>
//		) -> Session.ResolvedToolRun {
//			.calculator(run)
//		}
//
//		func resolvePartially(
//			_ run: PartialToolRun<ResolvableCalculatorTool>
//		) -> Session.PartiallyResolvedToolRun {
//			.calculator(run)
//		}
//	}
// }

@Generable
struct VectorSearch {
	var results: [String] = []
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

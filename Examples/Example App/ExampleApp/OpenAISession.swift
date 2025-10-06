// By Dennis Müller

import Foundation
import FoundationModels
import Observation
import OpenAISession

// TODO: resolvedStreaming response stuff also needs a partiallyGenerated variant

final class OpenAISession {
	@Tool var calculator = CalculatorTool()
	@Tool var weather = WeatherTool()
	@Grounding(Date.self) var currentDate
	@StructuredOutput(WeatherReport.self) var weatherReport

	@propertyWrapper
	struct Tool<ToolType: FoundationModels.Tool> where ToolType.Arguments: Generable, ToolType.Output: Generable {
		var wrappedValue: ToolType
		init(wrappedValue: ToolType) {
			self.wrappedValue = wrappedValue
		}
	}

	@propertyWrapper
	struct StructuredOutput<Output: SwiftAgent.StructuredOutput> {
		var wrappedValue: Output.Type
		init(_ wrappedValue: Output.Type) {
			self.wrappedValue = wrappedValue
		}
	}

	@propertyWrapper
	struct Grounding<Source: Codable & Sendable & Equatable> {
		var wrappedValue: Source.Type
		init(_ wrappedValue: Source.Type) {
			self.wrappedValue = wrappedValue
		}
	}

	typealias Adapter = OpenAIAdapter

	typealias ProviderType = OpenAISession

	let adapter: OpenAIAdapter

	@MainActor private var _transcript: SwiftAgent.Transcript = Transcript()

	@MainActor var transcript: SwiftAgent.Transcript {
		@storageRestrictions(initializes: _transcript)
		init(initialValue) {
			_transcript = initialValue
		}
		get {
			access(keyPath: \.transcript)
			return _transcript
		}
		set {
			guard shouldNotifyObservers(_transcript, newValue) else {
				_transcript = newValue
				return
			}

			withMutation(keyPath: \.transcript) {
				_transcript = newValue
			}
		}
		_modify {
			access(keyPath: \.transcript)
			_$observationRegistrar.willSet(self, keyPath: \.transcript)
			defer {
				_$observationRegistrar.didSet(self, keyPath: \.transcript)
			}
			yield &_transcript
		}
	}

	@MainActor private var _tokenUsage: TokenUsage = .init()

	@MainActor var tokenUsage: TokenUsage {
		@storageRestrictions(initializes: _tokenUsage)
		init(initialValue) {
			_tokenUsage = initialValue
		}
		get {
			access(keyPath: \.tokenUsage)
			return _tokenUsage
		}
		set {
			guard shouldNotifyObservers(_tokenUsage, newValue) else {
				_tokenUsage = newValue
				return
			}

			withMutation(keyPath: \.tokenUsage) {
				_tokenUsage = newValue
			}
		}
		_modify {
			access(keyPath: \.tokenUsage)
			_$observationRegistrar.willSet(self, keyPath: \.tokenUsage)
			defer {
				_$observationRegistrar.didSet(self, keyPath: \.tokenUsage)
			}
			yield &_tokenUsage
		}
	}

	let tools: [any ResolvableTool<ProviderType>]

	private let _$observationRegistrar = Observation.ObservationRegistrar()

	nonisolated func access(
		keyPath: KeyPath<ProviderType, some Any>,
	) {
		_$observationRegistrar.access(self, keyPath: keyPath)
	}

	nonisolated func withMutation<A>(
		keyPath: KeyPath<ProviderType, some Any>,
		_ mutation: () throws -> A,
	) rethrows -> A {
		try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
	}

	private nonisolated func shouldNotifyObservers<A>(
		_ lhs: A,
		_ rhs: A,
	) -> Bool {
		true
	}

	private nonisolated func shouldNotifyObservers<A: Equatable>(
		_ lhs: A,
		_ rhs: A,
	) -> Bool {
		lhs != rhs
	}

	private nonisolated func shouldNotifyObservers<A: AnyObject>(
		_ lhs: A,
		_ rhs: A,
	) -> Bool {
		lhs !== rhs
	}

	private nonisolated func shouldNotifyObservers<A: Equatable & AnyObject>(
		_ lhs: A,
		_ rhs: A,
	) -> Bool {
		lhs != rhs
	}

	init(
		instructions: String,
		apiKey: String,
	) {
		let tools: [any ResolvableTool<ProviderType>] = [
			ResolvableCalculatorTool(baseTool: _calculator.wrappedValue),
			ResolvableWeatherTool(baseTool: _weather.wrappedValue),
		]
		self.tools = tools

		adapter = OpenAIAdapter(
			tools: tools,
			instructions: instructions,
			configuration: .direct(apiKey: apiKey),
		)
	}

	init(
		instructions: String,
		configuration: OpenAIConfiguration,
	) {
		let tools: [any ResolvableTool<ProviderType>] = [
			ResolvableCalculatorTool(baseTool: _calculator.wrappedValue),
			ResolvableWeatherTool(baseTool: _weather.wrappedValue),
		]
		self.tools = tools

		adapter = OpenAIAdapter(
			tools: tools,
			instructions: instructions,
			configuration: configuration,
		)
	}

	enum GroundingSource: GroundingRepresentable {
		case currentDate(Date)
	}

	enum ResolvedToolRun: Equatable {
		case calculator(ToolRun<ResolvableCalculatorTool>)
		case weather(ToolRun<ResolvableWeatherTool>)
	}

	enum ResolvedStreamingToolRun: Equatable {
		case calculator(StreamingToolRun<ResolvableCalculatorTool>)
		case weather(StreamingToolRun<ResolvableWeatherTool>)
	}

	struct ResolvableCalculatorTool: ResolvableTool {
		typealias Provider = ProviderType
		typealias BaseTool = CalculatorTool
		typealias Arguments = BaseTool.Arguments
		typealias Output = BaseTool.Output

		private let baseTool: BaseTool

		init(baseTool: CalculatorTool) {
			self.baseTool = baseTool
		}

		var name: String {
			baseTool.name
		}

		var description: String {
			baseTool.description
		}

		var parameters: GenerationSchema {
			baseTool.parameters
		}

		func call(arguments: Arguments) async throws -> Output {
			try await baseTool.call(arguments: arguments)
		}

		func resolve(
			_ run: ToolRun<ResolvableCalculatorTool>,
		) -> Provider.ResolvedToolRun {
			.calculator(run)
		}

		func resolveStreaming(
			_ run: StreamingToolRun<ResolvableCalculatorTool>,
		) -> Provider.ResolvedStreamingToolRun {
			.calculator(run)
		}
	}

	struct ResolvableWeatherTool: ResolvableTool {
		typealias Provider = ProviderType
		typealias BaseTool = WeatherTool
		typealias Arguments = BaseTool.Arguments
		typealias Output = BaseTool.Output

		private let baseTool: BaseTool

		init(baseTool: WeatherTool) {
			self.baseTool = baseTool
		}

		var name: String {
			baseTool.name
		}

		var description: String {
			baseTool.description
		}

		var parameters: GenerationSchema {
			baseTool.parameters
		}

		func call(arguments: Arguments) async throws -> Output {
			try await baseTool.call(arguments: arguments)
		}

		func resolve(
			_ run: ToolRun<ResolvableWeatherTool>,
		) -> Provider.ResolvedToolRun {
			.weather(run)
		}

		func resolveStreaming(
			_ run: StreamingToolRun<ResolvableWeatherTool>,
		) -> Provider.ResolvedStreamingToolRun {
			.weather(run)
		}
	}

	enum StructuredOutputKind: String {
		case weatherReport = "WeatherReport"
	}

	enum ResolvedResponseSegment: Sendable {
		case text(String)

		case weatherReport(WeatherReport.Output)
		case unknown(GeneratedContent)
	}

	func resolvedSegments(from response: SwiftAgent.Transcript.Response) throws -> [ResolvedResponseSegment] {
		try response.segments.map { segment in
			switch segment {
			case let .text(textSegment):
				return .text(textSegment.content)
			case let .structure(structuredSegment):
				switch structuredSegment.typeName {
				case StructuredOutputKind.weatherReport.rawValue:
					let output = try WeatherReport.Output(structuredSegment.content)
					return .weatherReport(output)
				default:
					return .unknown(structuredSegment.content)
				}
			}
		}
	}
}

extension OpenAISession: LanguageModelProvider, @unchecked Sendable, nonisolated Observation.Observable {}

struct WeatherReport: StructuredOutput {
	let name = "weather_report"

	@Generable
	struct Output {
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

struct WeatherTool: Tool {
	let name = "get_weather"
	let description = "Gets current weather information for a location"

	@Generable
	struct Arguments {
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

// By Dennis Müller

import FoundationModels
import OpenAISession
import SimulatedSession
import SwiftUI

struct ConversationalAgentExampleView: View {
	@State private var userInput = ""
	@State private var transcript: SwiftAgent.Transcript<ContextSource>.PartiallyResolved<Tools> = .init([])
	@State private var session: OpenAIContextualSession<ContextSource>?

	// MARK: - Body

	var body: some View {
		Form {}
			.animation(.default, value: transcript)
			.formStyle(.grouped)
			.onAppear(perform: setupAgent)
	}

	// MARK: - Setup

	private func setupAgent() {
		session = ModelSession.openAI(
			tools: Tools.all,
			instructions: """
			You are a helpful assistant with access to several tools.
			Use the available tools when appropriate to help answer questions.
			Be concise but informative in your responses.
			""",
			context: ContextSource.self,
			configuration: .direct(apiKey: Secret.OpenAI.apiKey)
		)
	}

	// MARK: - Actions

	private func sendMessage() async {
		guard let session, userInput.isEmpty == false else { return }

		do {
			let stream = await session.streamResponse(to: userInput, supplying: [.currentDate(Date())]) { input, context in
				PromptTag("context") {
					for source in context.sources {
						switch source {
						case let .currentDate(date):
							PromptTag("current-date") { date }
						}
					}
					for linkPreview in context.linkPreviews {
						PromptTag("url-info", attributes: ["title": linkPreview.title ?? ""])
					}
				}

				PromptTag("input") {
					input
				}
			}

			userInput = ""

			for try await snapshot in stream {
				if let partiallyResolvedTranscript = snapshot.transcript.partiallyResolved(using: Tools.all) {
					transcript = partiallyResolvedTranscript
				}
			}
			
		} catch {
			print("Error", error.localizedDescription)
		}
	}
}

// MARK: - Prompt Context

private enum ContextSource: PromptContextSource {
	case currentDate(Date)
}

// MARK: - Tools

// TODO: Add "name" parameter with default "Tools"
#tools(accessLevel: .fileprivate) {
	CalculatorTool()
	WeatherTool()
}

private struct CalculatorTool: Tool, SwiftAgentTool {
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

private struct WeatherTool: Tool, SwiftAgentTool {
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
			humidity: weatherData.3
		)
	}
}

private enum ToolError: Error, LocalizedError {
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

#Preview {
	NavigationStack {
		ConversationalAgentExampleView()
			.navigationTitle("Agent Playground")
			.navigationBarTitleDisplayMode(.inline)
	}
	.preferredColorScheme(.dark)
}

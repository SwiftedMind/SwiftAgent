// By Dennis Müller

import Foundation
import FoundationModels
import Observation
import OpenAISession

// TODO: Fix unit tests

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

@SessionSchema
struct SessionSchema {
  @Tool var calculator = CalculatorTool()
  @Tool var weather = WeatherTool()
  @Grounding(Date.self) var currentDate
  @StructuredOutput(WeatherReport.self) var weatherReport
}

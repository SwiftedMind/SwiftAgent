// By Dennis Müller

import FoundationModels
import OpenAISession

struct WeatherTool: SwiftAgentTool {
  var name: String = "get_weather"
  var description: String = "Get current temperature for a given location."

  @Generable
  struct Arguments {
    var location: String
  }

  func call(arguments: Arguments) async throws -> String {
    "Sunny"
  }
}

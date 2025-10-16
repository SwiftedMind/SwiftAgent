// By Dennis Müller

import Foundation
import FoundationModels
import Observation
import OpenAISession

@SessionSchema
struct SessionSchema: LanguageModelSessionSchema {
  @Tool var calculator = CalculatorTool()
  @Tool var weather = WeatherTool()
  @Grounding(Date.self) var currentDate
  @StructuredOutput(WeatherReport.self) var weatherReport
}

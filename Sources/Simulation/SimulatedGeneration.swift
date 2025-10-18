// By Dennis Müller

import Foundation
import FoundationModels
import SwiftAgent

public enum SimulatedGeneration<StructuredOutput: SwiftAgent.StructuredOutput>: @unchecked Sendable {
  case reasoning(summary: String)
  case toolRun(tool: any MockableTool)
  case response(StructuredOutput.Schema)

  package var toolName: String? {
    switch self {
    case let .toolRun(tool):
      tool.tool.name
    default:
      nil
    }
  }
}

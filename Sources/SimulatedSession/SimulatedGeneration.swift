// By Dennis Müller

import Foundation
import FoundationModels
import SwiftAgent

public enum SimulatedGeneration: @unchecked Sendable {
  case reasoning(summary: String)
  case toolRun(tool: any MockableTool)
  case textResponse(String)
  case structuredResponse(GeneratedContent)

  package var toolName: String? {
    switch self {
    case let .toolRun(tool):
      tool.tool.name
    default:
      nil
    }
  }
}

public extension SimulatedGeneration {
  static func response(text: String) -> SimulatedGeneration {
    .textResponse(text)
  }

  static func response(content: some ConvertibleToGeneratedContent) -> SimulatedGeneration {
    .structuredResponse(content.generatedContent)
  }
}

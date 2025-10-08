// By Dennis Müller

import Foundation
import FoundationModels
import SwiftAgent

public enum SimulatedGeneration<Content>: Sendable where Content: Generable, Content: Sendable {
  case reasoning(summary: String)
  case toolRun(tool: any MockableAgentTool)
  case response(content: Content)

  package var toolName: String? {
    switch self {
    case let .toolRun(tool):
      tool.tool.name
    default:
      nil
    }
  }
}

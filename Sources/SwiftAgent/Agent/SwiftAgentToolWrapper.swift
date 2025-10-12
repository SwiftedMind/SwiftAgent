// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public struct SwiftAgentToolWrapper<Tool: FoundationModels.Tool>: SwiftAgentTool
  where Tool.Arguments: Generable, Tool.Output: Generable {
  private let tool: Tool

  public var name: String {
    tool.name
  }

  public var description: String {
    tool.description
  }

  public init(tool: Tool) {
    self.tool = tool
  }

  public func call(arguments: Tool.Arguments) async throws -> Tool.Output {
    try await tool.call(arguments: arguments)
  }
}

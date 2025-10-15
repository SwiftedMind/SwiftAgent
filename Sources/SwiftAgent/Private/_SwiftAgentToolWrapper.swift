// By Dennis Müller

import Foundation
import FoundationModels
import Internal

/// A wrapper around a `FoundationModels.Tool` that conforms to the `SwiftAgentTool` protocol.
///
/// - Note: This type is managed internally by the SDK. You generally do not interact with it directly.
public struct _SwiftAgentToolWrapper<Tool: FoundationModels.Tool>: SwiftAgentTool
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

// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public struct StructuredOutput<ResolvableOutput: ResolvableStructuredOutput>: Identifiable {
  public enum State {
    case inProgress(ResolvableOutput.Schema.PartiallyGenerated)
    case completed(ResolvableOutput.Schema)
    case failed(GeneratedContent)
  }

  private let raw: GeneratedContent
  public var id: String
  public var state: State

  public init(id: String, state: State, raw: GeneratedContent) {
    self.id = id
    self.state = state
    self.raw = raw
  }
}

extension StructuredOutput.State: Sendable where ResolvableOutput.Schema: Sendable,
  ResolvableOutput.Schema.PartiallyGenerated: Sendable {}
extension StructuredOutput.State: Equatable where ResolvableOutput.Schema: Equatable,
  ResolvableOutput.Schema.PartiallyGenerated: Equatable {}
extension StructuredOutput: Sendable where ResolvableOutput.Schema: Sendable,
  ResolvableOutput.Schema.PartiallyGenerated: Sendable {}
extension StructuredOutput: Equatable {
  public static func == (lhs: StructuredOutput<ResolvableOutput>, rhs: StructuredOutput<ResolvableOutput>) -> Bool {
    lhs.id == rhs.id && lhs.raw == rhs.raw
  }
}

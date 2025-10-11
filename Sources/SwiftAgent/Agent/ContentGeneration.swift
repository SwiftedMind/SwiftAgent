// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public struct ContentGeneration<ResolvableOutput: ResolvableStructuredOutput>: Identifiable {
  public enum State {
    case inProgress(ResolvableOutput.Base.Schema.PartiallyGenerated)
    case completed(ResolvableOutput.Base.Schema)
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

extension ContentGeneration.State: Sendable where ResolvableOutput.Base.Schema: Sendable,
  ResolvableOutput.Base.Schema.PartiallyGenerated: Sendable {}
extension ContentGeneration.State: Equatable where ResolvableOutput.Base.Schema: Equatable,
  ResolvableOutput.Base.Schema.PartiallyGenerated: Equatable {}
extension ContentGeneration: Sendable where ResolvableOutput.Base.Schema: Sendable,
  ResolvableOutput.Base.Schema.PartiallyGenerated: Sendable {}
extension ContentGeneration: Equatable {
  public static func == (lhs: ContentGeneration<ResolvableOutput>, rhs: ContentGeneration<ResolvableOutput>) -> Bool {
    lhs.id == rhs.id && lhs.raw == rhs.raw
  }
}

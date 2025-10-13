// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public struct StructuredOutputUpdate<Output: StructuredOutput>: Identifiable {
  public enum Phase {
    case partial(Output.Schema.PartiallyGenerated)
    case final(Output.Schema)
    case failed(GeneratedContent)
  }

  private let raw: GeneratedContent
  public var id: String
  public var phase: Phase

  public init(id: String, phase: Phase, raw: GeneratedContent) {
    self.id = id
    self.phase = phase
    self.raw = raw
  }
}

extension StructuredOutputUpdate.Phase: Sendable where Output.Schema: Sendable,
  Output.Schema.PartiallyGenerated: Sendable {}
extension StructuredOutputUpdate.Phase: Equatable where Output.Schema: Equatable,
  Output.Schema.PartiallyGenerated: Equatable {}
extension StructuredOutputUpdate: Sendable where Output.Schema: Sendable,
  Output.Schema.PartiallyGenerated: Sendable {}
extension StructuredOutputUpdate: Equatable {
  public static func == (lhs: StructuredOutputUpdate<Output>,
                         rhs: StructuredOutputUpdate<Output>) -> Bool {
    lhs.id == rhs.id && lhs.raw == rhs.raw
  }
}

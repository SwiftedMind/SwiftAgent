// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public struct StructuredOutputUpdate<DecodableOutput: DecodableStructuredOutput>: Identifiable {
  public enum Phase {
    case partial(DecodableOutput.Base.Schema.PartiallyGenerated)
    case final(DecodableOutput.Base.Schema)
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

extension StructuredOutputUpdate.Phase: Sendable where DecodableOutput.Base.Schema: Sendable,
  DecodableOutput.Base.Schema.PartiallyGenerated: Sendable {}
extension StructuredOutputUpdate.Phase: Equatable where DecodableOutput.Base.Schema: Equatable,
  DecodableOutput.Base.Schema.PartiallyGenerated: Equatable {}
extension StructuredOutputUpdate: Sendable where DecodableOutput.Base.Schema: Sendable,
  DecodableOutput.Base.Schema.PartiallyGenerated: Sendable {}
extension StructuredOutputUpdate: Equatable {
  public static func == (lhs: StructuredOutputUpdate<DecodableOutput>,
                         rhs: StructuredOutputUpdate<DecodableOutput>) -> Bool {
    lhs.id == rhs.id && lhs.raw == rhs.raw
  }
}

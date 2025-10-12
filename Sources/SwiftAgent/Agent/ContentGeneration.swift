// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public struct DecodedGeneratedContent<DecodableOutput: DecodableStructuredOutput>: Identifiable {
  public enum State {
    case inProgress(DecodableOutput.Base.Schema.PartiallyGenerated)
    case completed(DecodableOutput.Base.Schema)
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

extension DecodedGeneratedContent.State: Sendable where DecodableOutput.Base.Schema: Sendable,
  DecodableOutput.Base.Schema.PartiallyGenerated: Sendable {}
extension DecodedGeneratedContent.State: Equatable where DecodableOutput.Base.Schema: Equatable,
  DecodableOutput.Base.Schema.PartiallyGenerated: Equatable {}
extension DecodedGeneratedContent: Sendable where DecodableOutput.Base.Schema: Sendable,
  DecodableOutput.Base.Schema.PartiallyGenerated: Sendable {}
extension DecodedGeneratedContent: Equatable {
  public static func == (lhs: DecodedGeneratedContent<DecodableOutput>,
                         rhs: DecodedGeneratedContent<DecodableOutput>) -> Bool {
    lhs.id == rhs.id && lhs.raw == rhs.raw
  }
}

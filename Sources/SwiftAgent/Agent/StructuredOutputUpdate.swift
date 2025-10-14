// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public struct StructuredOutputUpdate<Output: StructuredOutput>: Identifiable {
  public enum Phase {
    case partial(Output.Schema.PartiallyGenerated)
    case final(Output.Schema)
  }

  @dynamicMemberLookup
  public struct Normalized {
    public var isFinal: Bool
    public var schema: Output.Schema.PartiallyGenerated

    init(isFinal: Bool, schema: Output.Schema.PartiallyGenerated) {
      self.isFinal = isFinal
      self.schema = schema
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<Output.Schema.PartiallyGenerated, Value>) -> Value {
      schema[keyPath: keyPath]
    }
  }

  public var raw: GeneratedContent
  public var id: String
  public var phase: Phase?
  public var normalized: Normalized?

  // TODO: Proper error type?
  public var error: GeneratedContent?

  public init(id: String, phase: Phase, raw: GeneratedContent) {
    self.id = id
    self.phase = phase
    self.raw = raw
    normalized = Self.makeNormalized(from: phase, raw: raw)
  }

  public init(id: String, error: GeneratedContent, raw: GeneratedContent) {
    self.id = id
    self.error = error
    self.raw = raw
  }
}

private extension StructuredOutputUpdate {
  static func makeNormalized(from phase: Phase, raw: GeneratedContent) -> Normalized? {
    switch phase {
    case let .partial(schema):
      Normalized(isFinal: false, schema: schema)
    case let .final(schema):
      Normalized(isFinal: true, schema: schema.asPartiallyGenerated())
    }
  }
}

extension StructuredOutputUpdate.Phase: Sendable where Output.Schema: Sendable,
  Output.Schema.PartiallyGenerated: Sendable {}
extension StructuredOutputUpdate.Phase: Equatable where Output.Schema: Equatable,
  Output.Schema.PartiallyGenerated: Equatable {}
extension StructuredOutputUpdate: Sendable where Output.Schema: Sendable,
  Output.Schema.PartiallyGenerated: Sendable {}
extension StructuredOutputUpdate.Normalized: Sendable where Output.Schema.PartiallyGenerated: Sendable {}
extension StructuredOutputUpdate: Equatable {
  public static func == (lhs: StructuredOutputUpdate<Output>,
                         rhs: StructuredOutputUpdate<Output>) -> Bool {
    lhs.id == rhs.id && lhs.raw == rhs.raw
  }
}

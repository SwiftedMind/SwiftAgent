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

  private let raw: GeneratedContent
  public var id: String
  public var phase: Phase

  /// Provides a UI-stable, partial-shaped view of the schema.
  /// Even when the underlying schema is final, this exposes it as
  /// `Output.Schema.PartiallyGenerated` so SwiftUI view identities remain stable.
  /// Use `isFinal` to determine whether the values represent the completed schema.
  public let normalized: Normalized?

  public init(id: String, phase: Phase, raw: GeneratedContent) {
    self.id = id
    self.phase = phase
    self.raw = raw
    normalized = Self.makeNormalized(from: phase, raw: raw)
  }
}

private extension StructuredOutputUpdate {
  static func makeNormalized(from phase: Phase, raw: GeneratedContent) -> Normalized? {
    switch phase {
    case let .partial(schema):
      Normalized(isFinal: false, schema: schema)
    case let .final(schema):
      Normalized(isFinal: true, schema: schema.asPartiallyGenerated())
    case .failed:
      nil
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

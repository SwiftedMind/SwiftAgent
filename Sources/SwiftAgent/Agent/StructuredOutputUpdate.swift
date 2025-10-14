// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public struct StructuredOutputUpdate<Output: StructuredOutput>: Identifiable {
  public enum Content {
    case partial(Output.Schema.PartiallyGenerated)
    case final(Output.Schema)
  }

  @dynamicMemberLookup
  public struct NormalizedContent {
    public var isFinal: Bool
    public var content: Output.Schema.PartiallyGenerated

    init(isFinal: Bool, content: Output.Schema.PartiallyGenerated) {
      self.isFinal = isFinal
      self.content = content
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<Output.Schema.PartiallyGenerated, Value>) -> Value {
      content[keyPath: keyPath]
    }
  }

  public var id: String
  public var rawContent: GeneratedContent
  public var content: Content?
  public var normalizedContent: NormalizedContent?
  public var error: GeneratedContent?

  public init(id: String, content: Content, rawContent: GeneratedContent) {
    self.id = id
    self.content = content
    self.rawContent = rawContent
    normalizedContent = Self.makeNormalized(from: content, raw: rawContent)
  }

  public init(id: String, error: GeneratedContent, rawContent: GeneratedContent) {
    self.id = id
    self.error = error
    self.rawContent = rawContent
  }

  public static func partial(id: String, json: String) throws -> StructuredOutputUpdate<Output> {
    let rawContent = try GeneratedContent(json: json)
    let content = try Output.Schema.PartiallyGenerated(rawContent)
    return StructuredOutputUpdate(id: id, content: .partial(content), rawContent: rawContent)
  }

  public static func final(id: String, json: String) throws -> StructuredOutputUpdate<Output> {
    let rawContent = try GeneratedContent(json: json)
    let content = try Output.Schema(rawContent)
    return StructuredOutputUpdate(id: id, content: .final(content), rawContent: rawContent)
  }

  public static func error(id: String, error: GeneratedContent) throws -> StructuredOutputUpdate<Output> {
    StructuredOutputUpdate(id: id, error: error, rawContent: error)
  }
}

private extension StructuredOutputUpdate {
  static func makeNormalized(from content: Content, raw: GeneratedContent) -> NormalizedContent? {
    switch content {
    case let .partial(content):
      NormalizedContent(isFinal: false, content: content)
    case let .final(content):
      NormalizedContent(isFinal: true, content: content.asPartiallyGenerated())
    }
  }
}

extension StructuredOutputUpdate.Content: Sendable where Output.Schema: Sendable,
  Output.Schema.PartiallyGenerated: Sendable {}
extension StructuredOutputUpdate.Content: Equatable where Output.Schema: Equatable,
  Output.Schema.PartiallyGenerated: Equatable {}
extension StructuredOutputUpdate: Sendable where Output.Schema: Sendable,
  Output.Schema.PartiallyGenerated: Sendable {}
extension StructuredOutputUpdate.NormalizedContent: Sendable where Output.Schema.PartiallyGenerated: Sendable {}
extension StructuredOutputUpdate: Equatable {
  public static func == (lhs: StructuredOutputUpdate<Output>,
                         rhs: StructuredOutputUpdate<Output>) -> Bool {
    lhs.id == rhs.id && lhs.rawContent == rhs.rawContent
  }
}

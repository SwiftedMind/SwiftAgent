import Foundation
import FoundationModels

/// Configuration options for text outputs from the Responses API.
public struct TextConfig: Codable, Hashable, Sendable {
  public enum Format: Hashable, Sendable {
    case text
    case generationSchema(schema: GenerationSchema, description: String? = nil, name: String, strict: Bool?)

    private enum CodingKeys: String, CodingKey {
      case type
      case schema
      case description
      case name
      case strict
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      switch self {
      case .text:
        try container.encode("text", forKey: .type)
      case let .generationSchema(schema, description, name, strict):
        try container.encode("json_schema", forKey: .type)
        try container.encode(schema, forKey: .schema)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(strict, forKey: .strict)
      }
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      switch type {
      case "text":
        self = .text
      case "json_schema":
        let schema = try container.decode(GenerationSchema.self, forKey: .schema)
        let description = try container.decodeIfPresent(String.self, forKey: .description)
        let name = try container.decode(String.self, forKey: .name)
        let strict = try container.decodeIfPresent(Bool.self, forKey: .strict)
        self = .generationSchema(schema: schema, description: description, name: name, strict: strict)
      default:
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported text format \(type)."))
      }
    }
  }

  public var format: Format

  public init(format: Format = .text) {
    self.format = format
  }
}

import Foundation
import FoundationModels

/// Tools that the model may invoke while generating a response.
public struct Tool: Codable, Hashable, Sendable {
  public struct Function: Codable, Hashable, Sendable {
    public var name: String
    public var description: String?
    public var parameters: GenerationSchema
    public var strict: Bool

    public init(name: String, description: String? = nil, parameters: GenerationSchema, strict: Bool = true) {
      self.name = name
      self.description = description
      self.parameters = parameters
      self.strict = strict
    }

    private enum CodingKeys: String, CodingKey {
      case name
      case description
      case parameters
      case strict
    }
  }

  public enum Choice: Hashable, Sendable {
    case auto
    case none
    case required
    case function(name: String)

    private enum CodingKeys: String, CodingKey {
      case type
      case function
    }

    private enum FunctionCodingKeys: String, CodingKey {
      case name
    }
  }

  public var type: String
  public var function: Function?

  public init(type: String, function: Function? = nil) {
    self.type = type
    self.function = function
  }

  public static func function(
    name: String,
    description: String?,
    parameters: GenerationSchema,
    strict: Bool
  ) -> Tool {
    Tool(type: "function", function: Function(name: name, description: description, parameters: parameters, strict: strict))
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case function
  }
}

extension Tool.Choice: Codable {
  public func encode(to encoder: Encoder) throws {
    switch self {
    case .auto:
      var container = encoder.singleValueContainer()
      try container.encode("auto")
    case .none:
      var container = encoder.singleValueContainer()
      try container.encode("none")
    case .required:
      var container = encoder.singleValueContainer()
      try container.encode("required")
    case let .function(name):
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode("function", forKey: .type)
      var functionContainer = container.nestedContainer(keyedBy: FunctionCodingKeys.self, forKey: .function)
      try functionContainer.encode(name, forKey: .name)
    }
  }

  public init(from decoder: Decoder) throws {
    if let singleValue = try? decoder.singleValueContainer() {
      if let raw = try? singleValue.decode(String.self) {
        switch raw {
        case "auto":
          self = .auto
        case "none":
          self = .none
        case "required":
          self = .required
        default:
          throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported tool choice \(raw)."))
        }
        return
      }
    }

    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case "function":
      let nested = try container.nestedContainer(keyedBy: FunctionCodingKeys.self, forKey: .function)
      let name = try nested.decode(String.self, forKey: .name)
      self = .function(name: name)
    default:
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported tool choice \(type)."))
    }
  }
}

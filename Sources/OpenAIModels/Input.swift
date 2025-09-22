import Foundation

/// Text, image, or file inputs to the Responses API.
public enum Input: Sendable {
  public enum ListItem: Sendable {
    case message(Message.Input)
    case item(Item.Input)
    case itemRef(id: String)
  }

  public enum Content: Sendable {
    public enum ContentItem: Sendable {
      case text(String)
    }

    case text(String)
    case list([ContentItem])
  }

  case text(String)
  case list([ListItem])
}

// MARK: - Codable

extension Input: Codable {
  public func encode(to encoder: Encoder) throws {
    switch self {
    case let .text(value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case let .list(items):
      var container = encoder.unkeyedContainer()
      for item in items {
        try container.encode(item)
      }
    }
  }

  public init(from decoder: Decoder) throws {
    if let stringValue = try? decoder.singleValueContainer().decode(String.self) {
      self = .text(stringValue)
      return
    }

    var container = try decoder.unkeyedContainer()
    var items: [ListItem] = []
    while !container.isAtEnd {
      let item = try container.decode(ListItem.self)
      items.append(item)
    }
    self = .list(items)
  }
}

extension Input.ListItem: Codable {
  private enum CodingKeys: String, CodingKey {
    case type
    case id
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .message(message):
      try container.encode("message", forKey: .type)
      try message.encode(to: encoder)
    case let .item(item):
      try container.encode(item.typeIdentifier, forKey: .type)
      try item.encode(to: encoder)
    case let .itemRef(id):
      try container.encode("item_reference", forKey: .type)
      try container.encode(id, forKey: .id)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case "message":
      let message = try Message.Input(from: decoder)
      self = .message(message)
    case "item_reference":
      let identifier = try container.decode(String.self, forKey: .id)
      self = .itemRef(id: identifier)
    default:
      let item = try Item.Input(from: decoder, type: type)
      self = .item(item)
    }
  }
}

extension Input.Content: Codable {
  public func encode(to encoder: Encoder) throws {
    switch self {
    case let .text(text):
      var container = encoder.unkeyedContainer()
      try container.encode(ContentItem.text(text))
    case let .list(items):
      var container = encoder.unkeyedContainer()
      for item in items {
        try container.encode(item)
      }
    }
  }

  public init(from decoder: Decoder) throws {
    if let stringValue = try? decoder.singleValueContainer().decode(String.self) {
      self = .text(stringValue)
      return
    }

    var container = try decoder.unkeyedContainer()
    var items: [ContentItem] = []
    while !container.isAtEnd {
      let item = try container.decode(ContentItem.self)
      items.append(item)
    }

    if items.count == 1, case let .text(text) = items[0] {
      self = .text(text)
    } else {
      self = .list(items)
    }
  }
}

extension Input.Content.ContentItem: Codable {
  private enum CodingKeys: String, CodingKey {
    case type
    case text
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .text(text):
      try container.encode("input_text", forKey: .type)
      try container.encode(text, forKey: .text)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case "input_text":
      let text = try container.decode(String.self, forKey: .text)
      self = .text(text)
    default:
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported content item type \(type)."))
    }
  }
}

// MARK: - Helpers

public extension Input.ListItem {
  static func message(role: Message.Role = .user, content: Input.Content, status: Message.Status? = nil) -> Self {
    .message(Message.Input(role: role, content: content, status: status))
  }

  static func item(_ item: Item.Input) -> Self {
    .item(item)
  }
}

public extension Input.Content {
  static func text(_ text: String) -> Input.Content {
    .text(text)
  }

  var text: String? {
    switch self {
    case let .text(value):
      return value
    case let .list(items):
      let pieces = items.compactMap { item -> String? in
        if case let .text(text) = item {
          return text
        }
        return nil
      }
      return pieces.isEmpty ? nil : pieces.joined(separator: " ")
    }
  }
}

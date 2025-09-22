import Foundation

public enum Message: Sendable {
  public enum Role: String, Codable, CaseIterable, Sendable {
    case user
    case system
    case assistant
    case developer
  }

  public enum Status: String, Codable, CaseIterable, Sendable {
    case completed
    case incomplete
    case inProgress = "in_progress"
  }

  public enum MessageContent: Sendable {
    case input(Input.Content)
    case output([Item.Output.Content])
  }

  public struct Input: Codable, Hashable, Sendable {
    public var role: Role
    public var status: Status?
    public var content: Input.Content

    public init(role: Role = .user, content: Input.Content, status: Status? = nil) {
      self.role = role
      self.status = status
      self.content = content
    }

    public var text: String? {
      content.text
    }

    private enum CodingKeys: String, CodingKey {
      case role
      case status
      case content
    }
  }

  public struct Output: Codable, Hashable, Sendable {
    public var content: [Item.Output.Content]
    public var id: String
    public var role: Role
    public var status: Status

    public init(content: [Item.Output.Content], id: String, role: Role = .assistant, status: Status) {
      self.content = content
      self.id = id
      self.role = role
      self.status = status
    }

    private enum CodingKeys: String, CodingKey {
      case content
      case id
      case role
      case status
    }

    public var text: String {
      content.map { $0.text }.joined()
    }
  }

  case input(Input)
  case output(Output)

  public var role: Role {
    switch self {
    case let .input(message):
      return message.role
    case let .output(message):
      return message.role
    }
  }

  public var content: MessageContent {
    switch self {
    case let .input(message):
      return .input(message.content)
    case let .output(message):
      return .output(message.content)
    }
  }

  public var status: Status? {
    switch self {
    case let .input(message):
      return message.status
    case let .output(message):
      return message.status
    }
  }

  public var id: String? {
    switch self {
    case .input:
      return nil
    case let .output(message):
      return message.id
    }
  }

  public var text: String? {
    switch self {
    case let .input(message):
      return message.text
    case let .output(message):
      return message.text
    }
  }
}

import Foundation

/// Items that form part of a model response or prompt history.
public enum Item: Sendable {
  public enum Input: Sendable {
    case inputMessage(Message.Input)
    case outputMessage(Message.Output)
    case functionCall(FunctionCall)
    case functionCallOutput(FunctionCallOutput)
    case reasoning(Reasoning)

    var typeIdentifier: String {
      switch self {
      case .inputMessage, .outputMessage:
        return "message"
      case .functionCall:
        return "function_call"
      case .functionCallOutput:
        return "function_call_output"
      case .reasoning:
        return "reasoning"
      }
    }
  }

  public enum Output: Sendable {
    public enum Content: Sendable {
      public enum Annotation: Hashable, Sendable {
        case fileCitation(fileId: String, index: UInt)
        case urlCitation(endIndex: UInt, startIndex: UInt, title: String, url: String)
        case filePath(fileId: String, index: UInt)
      }

      public struct LogProb: Codable, Hashable, Sendable {
        public struct AlternativeLogProb: Codable, Hashable, Sendable {
          public var bytes: [Int]
          public var logprob: Double
          public var token: String

          public init(bytes: [Int], logprob: Double, token: String) {
            self.bytes = bytes
            self.logprob = logprob
            self.token = token
          }
        }

        public var bytes: [Int]
        public var token: String
        public var logprob: Double
        public var topLogprobs: [AlternativeLogProb]?

        public init(bytes: [Int], token: String, logprob: Double, topLogprobs: [AlternativeLogProb]? = nil) {
          self.bytes = bytes
          self.token = token
          self.logprob = logprob
          self.topLogprobs = topLogprobs
        }

        private enum CodingKeys: String, CodingKey {
          case bytes
          case token
          case logprob
          case topLogprobs = "top_logprobs"
        }
      }

      case text(text: String, annotations: [Annotation], logprobs: [LogProb])
      case refusal(String)

      public var text: String {
        switch self {
        case let .text(text, _, _):
          return text
        case let .refusal(value):
          return value
        }
      }

      public var asText: String? {
        if case let .text(text, _, _) = self {
          return text
        }
        return nil
      }
    }

    case message(Message.Output)
    case functionCall(FunctionCall)
    case functionCallOutput(FunctionCallOutput)
    case reasoning(Reasoning)
    case unknown(String)
  }

  public struct FunctionCall: Codable, Hashable, Sendable {
    public enum Status: String, Codable, CaseIterable, Sendable {
      case completed
      case incomplete
      case inProgress = "in_progress"
    }

    public var arguments: String
    public var callId: String
    public var id: String
    public var name: String
    public var status: Status

    public init(arguments: String, callId: String, id: String, name: String, status: Status) {
      self.arguments = arguments
      self.callId = callId
      self.id = id
      self.name = name
      self.status = status
    }

    private enum CodingKeys: String, CodingKey {
      case arguments
      case callId = "call_id"
      case id
      case name
      case status
    }
  }

  public struct FunctionCallOutput: Codable, Hashable, Sendable {
    public var id: String?
    public var status: Item.FunctionCall.Status?
    public var callId: String
    public var output: String

    public init(id: String? = nil, status: Item.FunctionCall.Status? = nil, callId: String, output: String) {
      self.id = id
      self.status = status
      self.callId = callId
      self.output = output
    }

    private enum CodingKeys: String, CodingKey {
      case id
      case status
      case callId = "call_id"
      case output
    }
  }

  public struct Reasoning: Codable, Hashable, Sendable {
    public enum Status: String, Codable, CaseIterable, Sendable {
      case completed
      case incomplete
      case inProgress = "in_progress"
    }

    public enum Summary: Codable, Hashable, Sendable {
      case text(String)

      public var text: String {
        get {
          switch self {
          case let .text(value):
            return value
          }
        }
        set {
          switch self {
          case .text:
            self = .text(newValue)
          }
        }
      }

    }

    public var id: String
    public var summary: [Summary]
    public var status: Status?
    public var encryptedContent: String?

    public init(id: String, summary: [Summary] = [], status: Status? = nil, encryptedContent: String? = nil) {
      self.id = id
      self.summary = summary
      self.status = status
      self.encryptedContent = encryptedContent
    }

    private enum CodingKeys: String, CodingKey {
      case id
      case summary
      case status
      case encryptedContent = "encrypted_content"
    }
  }
}

// MARK: - Item.Input Codable

extension Item.Input: Codable {
  private enum CodingKeys: String, CodingKey {
    case type
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(typeIdentifier, forKey: .type)

    switch self {
    case let .inputMessage(message):
      try message.encode(to: encoder)
    case let .outputMessage(message):
      try message.encode(to: encoder)
    case let .functionCall(functionCall):
      try functionCall.encode(to: encoder)
    case let .functionCallOutput(output):
      try output.encode(to: encoder)
    case let .reasoning(reasoning):
      try reasoning.encode(to: encoder)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    try self.init(from: decoder, type: type)
  }

  init(from decoder: Decoder, type: String) throws {
    switch type {
    case "message":
      if let output = try? Message.Output(from: decoder) {
        self = .outputMessage(output)
      } else {
        let input = try Message.Input(from: decoder)
        self = .inputMessage(input)
      }
    case "function_call":
      let functionCall = try FunctionCall(from: decoder)
      self = .functionCall(functionCall)
    case "function_call_output":
      let output = try FunctionCallOutput(from: decoder)
      self = .functionCallOutput(output)
    case "reasoning":
      let reasoning = try Reasoning(from: decoder)
      self = .reasoning(reasoning)
    default:
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported item type \(type)."))
    }
  }
}

// MARK: - Item.Output Codable

extension Item.Output: Codable {
  private enum CodingKeys: String, CodingKey {
    case type
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .message(message):
      try container.encode("message", forKey: .type)
      try message.encode(to: encoder)
    case let .functionCall(functionCall):
      try container.encode("function_call", forKey: .type)
      try functionCall.encode(to: encoder)
    case let .functionCallOutput(output):
      try container.encode("function_call_output", forKey: .type)
      try output.encode(to: encoder)
    case let .reasoning(reasoning):
      try container.encode("reasoning", forKey: .type)
      try reasoning.encode(to: encoder)
    case let .unknown(type):
      try container.encode(type, forKey: .type)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try? decoder.container(keyedBy: CodingKeys.self)
    let type = try container?.decodeIfPresent(String.self, forKey: .type)

    switch type {
    case "message":
      let message = try Message.Output(from: decoder)
      self = .message(message)
    case "function_call":
      let call = try FunctionCall(from: decoder)
      self = .functionCall(call)
    case "function_call_output":
      let output = try FunctionCallOutput(from: decoder)
      self = .functionCallOutput(output)
    case "reasoning":
      let reasoning = try Reasoning(from: decoder)
      self = .reasoning(reasoning)
    case let .some(value):
      self = .unknown(value)
    case .none:
      let message = try Message.Output(from: decoder)
      self = .message(message)
    }
  }
}

// MARK: - Item.Output.Content Codable

extension Item.Output.Content: Codable {
  private enum CodingKeys: String, CodingKey {
    case type
    case text
    case annotations
    case logprobs
    case refusal
  }

  private enum AnnotationCodingKeys: String, CodingKey {
    case type
    case fileId = "file_id"
    case index
    case endIndex = "end_index"
    case startIndex = "start_index"
    case title
    case url
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .text(text, annotations, logprobs):
      try container.encode("output_text", forKey: .type)
      try container.encode(text, forKey: .text)
      try container.encode(annotations, forKey: .annotations)
      try container.encode(logprobs, forKey: .logprobs)
    case let .refusal(refusal):
      try container.encode("refusal", forKey: .type)
      try container.encode(refusal, forKey: .refusal)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case "output_text":
      let text = try container.decode(String.self, forKey: .text)
      let annotations = try container.decodeIfPresent([Annotation].self, forKey: .annotations) ?? []
      let logprobs = try container.decodeIfPresent([LogProb].self, forKey: .logprobs) ?? []
      self = .text(text: text, annotations: annotations, logprobs: logprobs)
    case "refusal":
      let refusal = try container.decode(String.self, forKey: .refusal)
      self = .refusal(refusal)
    default:
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported output content type \(type)."))
    }
  }

  private struct AnnotationWrapper: Codable, Hashable, Sendable {
    var annotation: Annotation

    init(annotation: Annotation) {
      self.annotation = annotation
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: AnnotationCodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      switch type {
      case "file_citation":
        let fileId = try container.decode(String.self, forKey: .fileId)
        let index = try container.decode(UInt.self, forKey: .index)
        annotation = .fileCitation(fileId: fileId, index: index)
      case "url_citation":
        let endIndex = try container.decode(UInt.self, forKey: .endIndex)
        let startIndex = try container.decode(UInt.self, forKey: .startIndex)
        let title = try container.decode(String.self, forKey: .title)
        let url = try container.decode(String.self, forKey: .url)
        annotation = .urlCitation(endIndex: endIndex, startIndex: startIndex, title: title, url: url)
      case "file_path":
        let fileId = try container.decode(String.self, forKey: .fileId)
        let index = try container.decode(UInt.self, forKey: .index)
        annotation = .filePath(fileId: fileId, index: index)
      default:
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported annotation type \(type)."))
      }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: AnnotationCodingKeys.self)
      switch annotation {
      case let .fileCitation(fileId, index):
        try container.encode("file_citation", forKey: .type)
        try container.encode(fileId, forKey: .fileId)
        try container.encode(index, forKey: .index)
      case let .urlCitation(endIndex, startIndex, title, url):
        try container.encode("url_citation", forKey: .type)
        try container.encode(endIndex, forKey: .endIndex)
        try container.encode(startIndex, forKey: .startIndex)
        try container.encode(title, forKey: .title)
        try container.encode(url, forKey: .url)
      case let .filePath(fileId, index):
        try container.encode("file_path", forKey: .type)
        try container.encode(fileId, forKey: .fileId)
        try container.encode(index, forKey: .index)
      }
    }
  }
}

extension Item.Output.Content.Annotation: Codable {
  public init(from decoder: Decoder) throws {
    let wrapper = try Item.Output.Content.AnnotationWrapper(from: decoder)
    self = wrapper.annotation
  }

  public func encode(to encoder: Encoder) throws {
    try Item.Output.Content.AnnotationWrapper(annotation: self).encode(to: encoder)
  }
}

extension Item.Reasoning.Summary {
  private enum CodingKeys: String, CodingKey {
    case type
    case text
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .text(text):
      try container.encode("summary_text", forKey: .type)
      try container.encode(text, forKey: .text)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case "summary_text":
      let text = try container.decode(String.self, forKey: .text)
      self = .text(text)
    default:
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported reasoning summary type \(type)."))
    }
  }
}

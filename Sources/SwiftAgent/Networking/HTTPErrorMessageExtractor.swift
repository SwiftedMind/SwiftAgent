// By Dennis Müller

import Foundation

/// Lightweight decoders for common API error envelopes (OpenAI, Anthropic, generic),
/// plus a safe string fallback so users see meaningful error messages.
enum HTTPErrorMessageExtractor {
  // MARK: - OpenAI

  /// { "error": { "message": "...", "type": "...", "param": "...", "code": ... } }
  private struct OpenAIEnvelope: Decodable {
    let error: Inner

    struct Inner: Decodable {
      let message: String
      let type: String?
      let param: String?
      let code: CodableValue?
    }
  }

  // MARK: - Anthropic

  /// 1) { "type": "error", "error": { "type": "...", "message": "..." } }
  private struct AnthropicEnvelopeV1: Decodable {
    let type: String?
    let error: Inner

    struct Inner: Decodable {
      let type: String?
      let message: String
    }
  }

  /// 2) { "error": { "type": "...", "message": "..." } }
  private struct AnthropicEnvelopeV2: Decodable {
    let error: Inner

    struct Inner: Decodable {
      let type: String?
      let message: String
    }
  }

  // MARK: - Generic Shapes

  private struct MessageEnvelope: Decodable {
    let message: String
  }

  private struct StringErrorEnvelope: Decodable {
    let error: String
  }

  // MARK: - Helpers

  /// Permissive decodable to hold unknown primitive types (string/number/bool/null)
  private enum CodableValue: Decodable, CustomStringConvertible {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if container.decodeNil() {
        self = .null
        return
      }
      if let s = try? container.decode(String.self) {
        self = .string(s)
        return
      }
      if let n = try? container.decode(Double.self) {
        self = .number(n)
        return
      }
      if let b = try? container.decode(Bool.self) {
        self = .bool(b)
        return
      }
      self = .null
    }

    var description: String {
      switch self {
      case let .string(s):
        s
      case let .number(n):
        String(n)
      case let .bool(b):
        String(b)
      case .null:
        "null"
      }
    }
  }

  // MARK: - API

  static func extract(from data: Data) -> String? {
    let decoder = JSONDecoder()

    // Try OpenAI envelope first
    if let openAI = try? decoder.decode(OpenAIEnvelope.self, from: data) {
      var parts: [String] = []
      parts.append(openAI.error.message)
      if let type = openAI.error.type, !type.isEmpty { parts.append("type: \(type)") }
      if let param = openAI.error.param, !param.isEmpty { parts.append("param: \(param)") }
      if let code = openAI.error.code { parts.append("code: \(code)") }
      return parts.joined(separator: " | ")
    }

    // Try Anthropic variants
    if let anthropic1 = try? decoder.decode(AnthropicEnvelopeV1.self, from: data) {
      var parts: [String] = []
      parts.append(anthropic1.error.message)
      if let type = anthropic1.error.type, !type.isEmpty { parts.append("type: \(type)") }
      return parts.joined(separator: " | ")
    }

    if let anthropic2 = try? decoder.decode(AnthropicEnvelopeV2.self, from: data) {
      var parts: [String] = []
      parts.append(anthropic2.error.message)
      if let type = anthropic2.error.type, !type.isEmpty { parts.append("type: \(type)") }
      return parts.joined(separator: " | ")
    }

    // Generic message/error strings
    if let msg = try? decoder.decode(MessageEnvelope.self, from: data) {
      return msg.message
    }
    if let err = try? decoder.decode(StringErrorEnvelope.self, from: data) {
      return err.error
    }

    // Fallback to body as UTF-8 string
    return string(from: data)
  }

  static func string(from data: Data) -> String? {
    guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
          !text.isEmpty else {
      return nil
    }

    return text
  }
}

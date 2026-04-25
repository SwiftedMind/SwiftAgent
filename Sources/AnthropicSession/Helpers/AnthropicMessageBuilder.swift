// By Dennis Müller

import Foundation
import FoundationModels
import SwiftAgent
import SwiftAnthropic

enum AnthropicMessageBuilder {
  private struct DraftMessage {
    var role: MessageParameter.Message.Role
    var content: [MessageParameter.Message.Content.ContentObject]
  }

  static func messages(
    from transcript: SwiftAgent.Transcript,
    includeThinking: Bool,
  ) throws -> [MessageParameter.Message] {
    var drafts: [DraftMessage] = []
    var pendingThinking: [MessageParameter.Message.Content.ContentObject] = []

    func append(
      role: MessageParameter.Message.Role,
      content: MessageParameter.Message.Content.ContentObject,
    ) {
      if role == .assistant, !pendingThinking.isEmpty {
        if var last = drafts.last, last.role == role {
          if last.content.isEmpty {
            last.content.append(contentsOf: pendingThinking)
          } else {
            last.content.insert(contentsOf: pendingThinking, at: 0)
          }
          pendingThinking.removeAll()
          last.content.append(content)
          drafts[drafts.count - 1] = last
          return
        }

        drafts.append(
          DraftMessage(
            role: role,
            content: pendingThinking + [content],
          ),
        )
        pendingThinking.removeAll()
        return
      }

      if var last = drafts.last, last.role == role {
        last.content.append(content)
        drafts[drafts.count - 1] = last
        return
      }

      drafts.append(
        DraftMessage(
          role: role,
          content: [content],
        ),
      )
    }

    for entry in transcript.entries {
      switch entry {
      case let .prompt(prompt):
        append(
          role: .user,
          content: .text(prompt.prompt),
        )

      case let .response(response):
        for segment in response.segments {
          switch segment {
          case let .text(textSegment):
            append(
              role: .assistant,
              content: .text(textSegment.content),
            )
          case let .structure(structuredSegment):
            append(
              role: .assistant,
              content: .text(structuredSegment.content.generatedContent.stableJsonString),
            )
          }
        }

      case let .toolCalls(toolCalls):
        for toolCall in toolCalls.calls {
          let input = try toolInput(from: toolCall.arguments)
          append(
            role: .assistant,
            content: .toolUse(toolCall.callId, toolCall.toolName, input),
          )
        }

      case let .toolOutput(toolOutput):
        let output: String = switch toolOutput.segment {
        case let .text(textSegment):
          textSegment.content
        case let .structure(structuredSegment):
          structuredSegment.content.generatedContent.stableJsonString
        }

        append(
          role: .user,
          content: .toolResult(toolOutput.callId, output, isError: nil, cacheControl: nil),
        )

      case let .reasoning(reasoning):
        guard includeThinking else {
          break
        }

        let summaryText = reasoning.summary.joined(separator: "\n")
          .trimmingCharacters(in: .whitespacesAndNewlines)

        if !summaryText.isEmpty {
          let signature = reasoning.encryptedReasoning ?? ""
          pendingThinking.append(.thinking(summaryText, signature))
        } else if let encryptedReasoning = reasoning.encryptedReasoning,
                  !encryptedReasoning.isEmpty {
          pendingThinking.append(.redactedThinking(encryptedReasoning))
        }
      }
    }

    if !pendingThinking.isEmpty,
       let lastAssistantIndex = drafts.lastIndex(where: { $0.role == .assistant }) {
      if drafts[lastAssistantIndex].content.isEmpty {
        drafts[lastAssistantIndex].content.append(contentsOf: pendingThinking)
      } else {
        drafts[lastAssistantIndex].content.insert(contentsOf: pendingThinking, at: 0)
      }
      pendingThinking.removeAll()
    }

    let messages = drafts.map { draft in
      let content: MessageParameter.Message.Content = if draft.content.count == 1,
                                                         case let .text(text) = draft.content[0] {
        .text(text)
      } else {
        .list(draft.content)
      }

      return MessageParameter.Message(
        role: draft.role,
        content: content,
      )
    }

    if let first = messages.first,
       first.role != MessageParameter.Message.Role.user.rawValue {
      throw GenerationError.requestFailed(
        reason: .invalidRequestConfiguration,
        detail: "Anthropic messages must start with a user role.",
      )
    }

    return messages
  }

  static func toolInput(
    from generatedContent: GeneratedContent,
  ) throws -> MessageResponse.Content.Input {
    let data = try jsonData(from: generatedContent)
    return try JSONDecoder().decode(MessageResponse.Content.Input.self, from: data)
  }

  static func generatedContent(
    from input: MessageResponse.Content.Input,
  ) throws -> GeneratedContent {
    let data = try JSONEncoder().encode(input)
    let json = String(decoding: data, as: UTF8.self)
    return try GeneratedContent(json: json)
  }

  private static func jsonData(
    from generatedContent: GeneratedContent,
  ) throws -> Data {
    let json = generatedContent.stableJsonString
    guard let data = json.data(using: .utf8) else {
      throw GenerationError.structuredContentParsingFailed(
        .init(rawContent: json, underlyingError: GenerationError.unknown),
      )
    }

    return data
  }
}

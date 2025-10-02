// By Dennis Müller

import EventSource
import Foundation
import OpenAI
import SwiftAgent

/// Decodes raw Server-Sent Events coming from OpenAI's Responses API into `ResponseStreamEvent` values.
public struct OpenAIResponseStreamEventDecoder: Sendable {
	private let jsonDecoder: JSONDecoder

	public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
		self.jsonDecoder = jsonDecoder
	}

	/// Attempts to decode a streaming event. Returns `nil` when the event has no `event` name or payload.
	public func decodeEvent(from event: EventSource.Event) throws -> ResponseStreamEvent? {
		guard let eventName = event.event,
		      let payloadData = event.data.data(using: .utf8),
		      let kind = OpenAIResponseStreamEventKind(rawValue: eventName)
		else {
			return nil
		}

		return try decode(kind: kind, payloadData: payloadData)
	}

	private func decode(kind: OpenAIResponseStreamEventKind, payloadData: Data) throws -> ResponseStreamEvent {
		let decodedEvent: ResponseStreamEvent = switch kind {
		case .responseCreated:
			try decode(payloadData, as: ResponseStreamEvent.created)
		case .responseInProgress:
			try decode(payloadData, as: ResponseStreamEvent.inProgress)
		case .responseCompleted:
			try decode(payloadData, as: ResponseStreamEvent.completed)
		case .responseFailed:
			try decode(payloadData, as: ResponseStreamEvent.failed)
		case .responseIncomplete:
			try decode(payloadData, as: ResponseStreamEvent.incomplete)
		case .responseQueued:
			try decode(payloadData, as: ResponseStreamEvent.queued)
		case .responseOutputItemAdded:
			try decode(payloadData) { ResponseStreamEvent.outputItem(.added($0)) }
		case .responseOutputItemDone:
			try decode(payloadData) { ResponseStreamEvent.outputItem(.done($0)) }
		case .responseContentPartAdded:
			try decode(payloadData) { ResponseStreamEvent.contentPart(.added($0)) }
		case .responseContentPartDone:
			try decode(payloadData) { ResponseStreamEvent.contentPart(.done($0)) }
		case .responseOutputTextDelta:
			try decode(payloadData) { ResponseStreamEvent.outputText(.delta($0)) }
		case .responseOutputTextDone:
			try decode(payloadData) { ResponseStreamEvent.outputText(.done($0)) }
		case .responseRefusalDelta:
			try decode(payloadData) { ResponseStreamEvent.refusal(.delta($0)) }
		case .responseRefusalDone:
			try decode(payloadData) { ResponseStreamEvent.refusal(.done($0)) }
		case .responseFunctionCallArgumentsDelta:
			try decode(payloadData) { ResponseStreamEvent.functionCallArguments(.delta($0)) }
		case .responseFunctionCallArgumentsDone:
			try decode(payloadData) { ResponseStreamEvent.functionCallArguments(.done($0)) }
		case .responseFileSearchCallInProgress:
			try decode(payloadData) { ResponseStreamEvent.fileSearchCall(.inProgress($0)) }
		case .responseFileSearchCallSearching:
			try decode(payloadData) { ResponseStreamEvent.fileSearchCall(.searching($0)) }
		case .responseFileSearchCallCompleted:
			try decode(payloadData) { ResponseStreamEvent.fileSearchCall(.completed($0)) }
		case .responseWebSearchCallInProgress:
			try decode(payloadData) { ResponseStreamEvent.webSearchCall(.inProgress($0)) }
		case .responseWebSearchCallSearching:
			try decode(payloadData) { ResponseStreamEvent.webSearchCall(.searching($0)) }
		case .responseWebSearchCallCompleted:
			try decode(payloadData) { ResponseStreamEvent.webSearchCall(.completed($0)) }
		case .responseReasoningSummaryPartAdded:
			try decode(payloadData) { ResponseStreamEvent.reasoningSummaryPart(.added($0)) }
		case .responseReasoningSummaryPartDone:
			try decode(payloadData) { ResponseStreamEvent.reasoningSummaryPart(.done($0)) }
		case .responseReasoningSummaryTextDelta:
			try decode(payloadData) { ResponseStreamEvent.reasoningSummaryText(.delta($0)) }
		case .responseReasoningSummaryTextDone:
			try decode(payloadData) { ResponseStreamEvent.reasoningSummaryText(.done($0)) }
		case .responseReasoningDelta:
			try decode(payloadData) { ResponseStreamEvent.reasoning(.delta($0)) }
		case .responseReasoningDone:
			try decode(payloadData) { ResponseStreamEvent.reasoning(.done($0)) }
		case .responseReasoningSummaryDelta:
			try decode(payloadData) { ResponseStreamEvent.reasoningSummary(.delta($0)) }
		case .responseReasoningSummaryDone:
			try decode(payloadData) { ResponseStreamEvent.reasoningSummary(.done($0)) }
		case .responseOutputTextAnnotationAdded:
			try decode(payloadData) { ResponseStreamEvent.outputTextAnnotation(.added($0)) }
		case .responseImageGenerationCallCompleted:
			try decode(payloadData) { ResponseStreamEvent.imageGenerationCall(.completed($0)) }
		case .responseImageGenerationCallGenerating:
			try decode(payloadData) { ResponseStreamEvent.imageGenerationCall(.generating($0)) }
		case .responseImageGenerationCallInProgress:
			try decode(payloadData) { ResponseStreamEvent.imageGenerationCall(.inProgress($0)) }
		case .responseImageGenerationCallPartialImage:
			try decode(payloadData) { ResponseStreamEvent.imageGenerationCall(.partialImage($0)) }
		case .responseMcpCallArgumentsDelta:
			try decode(payloadData) { ResponseStreamEvent.mcpCallArguments(.delta($0)) }
		case .responseMcpCallArgumentsDone:
			try decode(payloadData) { ResponseStreamEvent.mcpCallArguments(.done($0)) }
		case .responseMcpCallCompleted:
			try decode(payloadData) { ResponseStreamEvent.mcpCall(.completed($0)) }
		case .responseMcpCallFailed:
			try decode(payloadData) { ResponseStreamEvent.mcpCall(.failed($0)) }
		case .responseMcpCallInProgress:
			try decode(payloadData) { ResponseStreamEvent.mcpCall(.inProgress($0)) }
		case .responseMcpListToolsCompleted:
			try decode(payloadData) { ResponseStreamEvent.mcpListTools(.completed($0)) }
		case .responseMcpListToolsFailed:
			try decode(payloadData) { ResponseStreamEvent.mcpListTools(.failed($0)) }
		case .responseMcpListToolsInProgress:
			try decode(payloadData) { ResponseStreamEvent.mcpListTools(.inProgress($0)) }
		case .responseAudioDelta:
			try decode(payloadData) { ResponseStreamEvent.audio(.delta($0)) }
		case .responseAudioDone:
			try decode(payloadData) { ResponseStreamEvent.audio(.done($0)) }
		case .responseAudioTranscriptDelta:
			try decode(payloadData) { ResponseStreamEvent.audioTranscript(.delta($0)) }
		case .responseAudioTranscriptDone:
			try decode(payloadData) { ResponseStreamEvent.audioTranscript(.done($0)) }
		case .responseCodeInterpreterCallCodeDelta:
			try decode(payloadData) { payload in
				ResponseStreamEvent.codeInterpreterCall(.code(.delta(payload)))
			}
		case .responseCodeInterpreterCallCodeDone:
			try decode(payloadData) { payload in
				ResponseStreamEvent.codeInterpreterCall(.code(.done(payload)))
			}
		case .responseCodeInterpreterCallInProgress:
			try decode(payloadData) { ResponseStreamEvent.codeInterpreterCall(.inProgress($0)) }
		case .responseCodeInterpreterCallInterpreting:
			try decode(payloadData) { ResponseStreamEvent.codeInterpreterCall(.interpreting($0)) }
		case .responseCodeInterpreterCallCompleted:
			try decode(payloadData) { ResponseStreamEvent.codeInterpreterCall(.completed($0)) }
		case .error:
			try decodeErrorEvent(from: payloadData)
		}

		return decodedEvent
	}

	private func decode<Payload: Decodable>(
		_ payloadData: Data,
		as transform: (Payload) -> ResponseStreamEvent,
	) throws -> ResponseStreamEvent {
		let payload: Payload = try decodePayload(from: payloadData)
		return transform(payload)
	}

	private func decodeErrorEvent(from payloadData: Data) throws -> ResponseStreamEvent {
		do {
			return try decode(payloadData) { ResponseStreamEvent.error($0) }
		} catch SSEError.decodingFailed {
			// The live Responses API sometimes nests the error details inside an `error` object
			// instead of the documented flat payload. Keep decoding resilient by handling that
			// variant locally without changing the upstream OpenAI SDK types.
			return try decodeFallbackErrorEvent(from: payloadData)
		}
	}

	private func decodeFallbackErrorEvent(from payloadData: Data) throws -> ResponseStreamEvent {
		let payload: FallbackResponseErrorEventPayload = try decodePayload(from: payloadData)
		let eventType = Components.Schemas.ResponseErrorEvent._TypePayload(rawValue: payload.type) ?? .error
		let errorEvent = Components.Schemas.ResponseErrorEvent(
			_type: eventType,
			code: payload.error.code,
			message: payload.error.message,
			param: payload.error.param,
			sequenceNumber: payload.sequenceNumber,
		)
		return ResponseStreamEvent.error(errorEvent)
	}

	private func decodePayload<Payload: Decodable>(from payloadData: Data) throws -> Payload {
		do {
			return try jsonDecoder.decode(Payload.self, from: payloadData)
		} catch {
			throw SSEError.decodingFailed(underlying: error, data: payloadData)
		}
	}
}

private struct FallbackResponseErrorEventPayload: Decodable {
	struct ErrorPayload: Decodable {
		let type: String
		let code: String?
		let message: String
		let param: String?
	}

	let type: String
	let sequenceNumber: Int
	let error: ErrorPayload

	// Mirrors the schema used by the production Responses API where error fields are nested.

	private enum CodingKeys: String, CodingKey {
		case type
		case sequenceNumber = "sequence_number"
		case error
	}
}

private enum OpenAIResponseStreamEventKind: String {
	case responseCreated = "response.created"
	case responseInProgress = "response.in_progress"
	case responseCompleted = "response.completed"
	case responseFailed = "response.failed"
	case responseIncomplete = "response.incomplete"
	case responseQueued = "response.queued"

	case responseOutputItemAdded = "response.output_item.added"
	case responseOutputItemDone = "response.output_item.done"

	case responseContentPartAdded = "response.content_part.added"
	case responseContentPartDone = "response.content_part.done"

	case responseOutputTextDelta = "response.output_text.delta"
	case responseOutputTextDone = "response.output_text.done"

	case responseRefusalDelta = "response.refusal.delta"
	case responseRefusalDone = "response.refusal.done"

	case responseFunctionCallArgumentsDelta = "response.function_call_arguments.delta"
	case responseFunctionCallArgumentsDone = "response.function_call_arguments.done"

	case responseFileSearchCallInProgress = "response.file_search_call.in_progress"
	case responseFileSearchCallSearching = "response.file_search_call.searching"
	case responseFileSearchCallCompleted = "response.file_search_call.completed"

	case responseWebSearchCallInProgress = "response.web_search_call.in_progress"
	case responseWebSearchCallSearching = "response.web_search_call.searching"
	case responseWebSearchCallCompleted = "response.web_search_call.completed"

	case responseReasoningSummaryPartAdded = "response.reasoning_summary_part.added"
	case responseReasoningSummaryPartDone = "response.reasoning_summary_part.done"

	case responseReasoningSummaryTextDelta = "response.reasoning_summary_text.delta"
	case responseReasoningSummaryTextDone = "response.reasoning_summary_text.done"

	case responseReasoningDelta = "response.reasoning.delta"
	case responseReasoningDone = "response.reasoning.done"
	case responseReasoningSummaryDelta = "response.reasoning_summary.delta"
	case responseReasoningSummaryDone = "response.reasoning_summary.done"

	case responseOutputTextAnnotationAdded = "response.output_text_annotation.added"

	case responseImageGenerationCallCompleted = "response.image_generation_call.completed"
	case responseImageGenerationCallGenerating = "response.image_generation_call.generating"
	case responseImageGenerationCallInProgress = "response.image_generation_call.in_progress"
	case responseImageGenerationCallPartialImage = "response.image_generation_call.partial_image"

	// 😌(🤬) Once OpenAI fixed the issue, please rename this back to
	// response.mcp_call.arguments.delta
	// response.mcp_call.arguments.done
	case responseMcpCallArgumentsDelta = "response.mcp_call_arguments.delta"
	case responseMcpCallArgumentsDone = "response.mcp_call_arguments.done"

	case responseMcpCallCompleted = "response.mcp_call.completed"
	case responseMcpCallFailed = "response.mcp_call.failed"
	case responseMcpCallInProgress = "response.mcp_call.in_progress"

	case responseMcpListToolsCompleted = "response.mcp_list_tools.completed"
	case responseMcpListToolsFailed = "response.mcp_list_tools.failed"
	case responseMcpListToolsInProgress = "response.mcp_list_tools.in_progress"

	case responseAudioDelta = "response.audio.delta"
	case responseAudioDone = "response.audio.done"
	case responseAudioTranscriptDelta = "response.audio_transcript.delta"
	case responseAudioTranscriptDone = "response.audio_transcript.done"

	case responseCodeInterpreterCallCodeDelta = "response.code_interpreter_call.code.delta"
	case responseCodeInterpreterCallCodeDone = "response.code_interpreter_call.code.done"
	case responseCodeInterpreterCallInProgress = "response.code_interpreter_call.in_progress"
	case responseCodeInterpreterCallInterpreting = "response.code_interpreter_call.interpreting"
	case responseCodeInterpreterCallCompleted = "response.code_interpreter_call.completed"

	case error
}

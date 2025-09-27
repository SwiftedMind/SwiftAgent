// By Dennis Müller

import EventSource
import Foundation
@testable import SwiftAgent

actor RecordedResponseReplayingHTTPClient: HTTPClient {
	enum ReplayError: Error, LocalizedError {
		case noRecordedResponsesRemaining
		case invalidUTF8RecordedResponse

		var errorDescription: String? {
			switch self {
			case .noRecordedResponsesRemaining:
				"Attempted to consume more recorded HTTP responses than were provided."
			case .invalidUTF8RecordedResponse:
				"Recorded HTTP response could not be converted to UTF-8 data."
			}
		}
	}

	private var pendingRecordedResponses: [String]

	init(recordedResponses: [String]) {
		pendingRecordedResponses = recordedResponses
	}

	init(recordedResponse: String) {
		pendingRecordedResponses = [recordedResponse]
	}

	nonisolated func send<ResponseBody>(
		path: String,
		method: HTTPMethod,
		queryItems: [URLQueryItem]?,
		headers: [String: String]?,
		body: (some Encodable)?,
		responseType: ResponseBody.Type,
	) async throws -> ResponseBody where ResponseBody: Decodable {
		let response = try await takeNextRecordedResponse()
		guard let data = response.data(using: .utf8) else {
			throw ReplayError.invalidUTF8RecordedResponse
		}

		return try JSONDecoder().decode(ResponseBody.self, from: data)
	}

	nonisolated func stream(
		path: String,
		method: HTTPMethod,
		headers: [String: String],
		body: (some Encodable)?,
	) -> AsyncThrowingStream<EventSource.Event, any Error> {
		AsyncThrowingStream { continuation in
			let task = Task<Void, Never> {
				do {
					let response = try await takeNextRecordedResponse()
					for event in await parseEvents(from: response) {
						continuation.yield(event)
					}
					continuation.finish()
				} catch {
					continuation.yield(with: .failure(error))
					continuation.finish()
				}
			}

			continuation.onTermination = { _ in
				task.cancel()
			}
		}
	}
}

private extension RecordedResponseReplayingHTTPClient {
	func takeNextRecordedResponse() throws -> String {
		guard let response = pendingRecordedResponses.first else {
			throw ReplayError.noRecordedResponsesRemaining
		}

		pendingRecordedResponses.removeFirst()
		return response
	}

	/// Helper to consume a string and get all dispatched events
	func parseEvents(
		from input: String,
		using parser: EventSource.Parser = EventSource.Parser(),
	) async -> [EventSource.Event] {
		for byte in input.utf8 {
			await parser.consume(byte)
		}
		await parser.finish()
		var events: [EventSource.Event] = []
		while let event = await parser.getNextEvent() {
			events.append(event)
		}
		return events
	}
}

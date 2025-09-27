// By Dennis Müller

import EventSource
import Foundation
@testable import SwiftAgent

struct MockHTTPClient: HTTPClient {
	private var response: String

	init(response: String) {
		self.response = response
	}

	func send<ResponseBody>(
		path: String,
		method: HTTPMethod,
		queryItems: [URLQueryItem]?,
		headers: [String: String]?,
		body: (some Encodable)?,
		responseType: ResponseBody.Type
	) async throws -> ResponseBody where ResponseBody: Decodable {
		try JSONDecoder().decode(ResponseBody.self, from: response.data(using: .utf8)!)
	}

	func stream(
		path: String,
		method: HTTPMethod,
		headers: [String: String],
		body: (some Encodable)?
	) -> AsyncThrowingStream<EventSource.Event, any Error> {
		.init { continuation in
			let task = Task<Void, Never> {
				for event in await getEvents(from: response) {
					continuation.yield(event)
				}
				continuation.finish()
			}

			continuation.onTermination = { _ in
				task.cancel()
			}
		}
	}
}

private extension MockHTTPClient {
	/// Helper to consume a string and get all dispatched events
	private func getEvents(
		from input: String,
		parser: EventSource.Parser = EventSource.Parser()
	) async -> [EventSource.Event] {
		for byte in input.utf8 {
			await parser.consume(byte)
		}
		// Call finish to process any buffered line and dispatch pending event based on current parser logic.
		await parser.finish()
		var events: [EventSource.Event] = []
		while let event = await parser.getNextEvent() {
			events.append(event)
		}
		return events
	}
}

// By Dennis Müller

import EventSource
import Foundation

public extension URLSessionHTTPClient {
	// MARK: - Public API (provider-agnostic)

	/// Opens a Server-Sent Events stream and yields `SSEEvent` frames as they arrive.
	///
	/// - Parameters:
	///   - path: Relative API path (joined with the client's `baseURL`).
	///   - method: HTTP method to use. Defaults to `.post` for response streaming APIs.
	///   - headers: Additional headers. `Accept: text/event-stream` is set automatically.
	///   - body: Optional JSON body (encoded with the client's JSON encoder).
	/// - Returns: `AsyncThrowingStream<SSEEvent, Error>`.
	func stream(
		path: String,
		method: HTTPMethod = .post,
		headers: [String: String] = [:],
		body: (some Encodable)? = nil,
	) -> AsyncThrowingStream<EventSource.Event, Error> {
		let encodedBodyResult = Result<Data?, Error> {
			try body.map { try configuration.jsonEncoder.encode($0) }
		}

		// Use explicit unbounded buffering to avoid back‑pressure when callers
		// temporarily pause consumption (e.g. while awaiting tool execution).
		return AsyncThrowingStream(bufferingPolicy: .unbounded) { continuation in
			let task = Task {
				do {
					let requestBody = try encodedBodyResult.get()
					let url = try makeURL(path: path, queryItems: nil)
					var request = URLRequest(url: url)
					request.httpMethod = method.rawValue
					request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
					if requestBody != nil {
						request.setValue("application/json", forHTTPHeaderField: "Content-Type")
					}

					for (headerField, headerValue) in configuration.defaultHeaders {
						request.setValue(headerValue, forHTTPHeaderField: headerField)
					}

					for (headerField, headerValue) in headers {
						request.setValue(headerValue, forHTTPHeaderField: headerField)
					}

					request.httpBody = requestBody

					if let prepareRequest = configuration.interceptors.prepareRequest {
						try await prepareRequest(&request)
					}

					NetworkLog.request(request)

					var (asyncBytes, response) = try await urlSession.bytes(for: request)

					if let httpResponse = response as? HTTPURLResponse,
					   httpResponse.statusCode == 401,
					   let onUnauthorized = configuration.interceptors.onUnauthorized,
					   await onUnauthorized(httpResponse, nil, request) {
						if let prepareRequest = configuration.interceptors.prepareRequest {
							try await prepareRequest(&request)
						}
						NetworkLog.request(request)
						(asyncBytes, response) = try await urlSession.bytes(for: request)
					}

					guard let httpResponse = response as? HTTPURLResponse else {
						throw SSEError.invalidResponse
					}
					guard (200..<300).contains(httpResponse.statusCode) else {
						let errorPreview = try await readPrefix(from: asyncBytes, maxLength: 4 * 1024)
						NetworkLog.response(response, data: errorPreview)
						throw SSEError.badStatus(code: httpResponse.statusCode, body: errorPreview)
					}

					NetworkLog.response(response, data: nil)

					for try await event in asyncBytes.events {
						continuation.yield(event)
					}

					continuation.finish()
				} catch is CancellationError {
					continuation.finish(throwing: SSEError.cancelled)
				} catch {
					continuation.finish(throwing: error)
				}
			}

			continuation.onTermination = { @Sendable _ in task.cancel() }
		}
	}

	/// Collect up to `maxLength` bytes from an `URLSession.AsyncBytes` stream into `Data`.
	/// Consumes from the stream; intended for error logging where the stream will not be reused.
	private func readPrefix(from bytes: URLSession.AsyncBytes, maxLength: Int) async throws -> Data {
		var collectedBytes = Data()
		collectedBytes.reserveCapacity(maxLength)
		var iterator = bytes.makeAsyncIterator()
		while collectedBytes.count < maxLength, let byte = try await iterator.next() {
			collectedBytes.append(byte)
		}
		return collectedBytes
	}
}

/// Errors that can occur while working with Server-Sent Events streams.
public enum SSEError: Error, LocalizedError, Sendable {
	case invalidResponse
	case badStatus(code: Int, body: Data?)
	case notEventStream(contentType: String?)
	case cancelled
	case decodingFailed(underlying: Error, data: Data)

	public var errorDescription: String? {
		switch self {
		case .invalidResponse:
			"Invalid response (no HTTPURLResponse)."
		case let .badStatus(code, _):
			"HTTP \(code) while opening SSE stream."
		case let .notEventStream(contentType):
			"Expected text/event-stream, got: \(contentType ?? "nil")."
		case .cancelled:
			"Stream cancelled."
		case let .decodingFailed(underlying, _):
			"Failed to decode SSE data: \(underlying.localizedDescription)"
		}
	}
}

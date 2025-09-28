// By Dennis Müller

import EventSource
import Foundation
@testable import Internal
@testable import OpenAISession

extension OpenAIConfiguration {
	static func recording(apiKey: String) -> OpenAIConfiguration {
		let encoder = JSONEncoder()

		encoder.outputFormatting = .sortedKeys

		let decoder = JSONDecoder()
		// Keep defaults; OpenAI models define their own coding keys

		let interceptors = HTTPClientInterceptors(
			prepareRequest: { request in
				request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
			},
			onUnauthorized: { _, _, _ in
				// Let the caller decide how to refresh; default is not to retry
				false
			}
		)

		let config = HTTPClientConfiguration(
			baseURL: URL(string: "https://api.openai.com")!,
			defaultHeaders: [:],
			timeout: 60,
			jsonEncoder: encoder,
			jsonDecoder: decoder,
			interceptors: interceptors
		)

		return OpenAIConfiguration(httpClient: RecordHTTPClient(configuration: config))
	}
}

actor RecordHTTPClient: HTTPClient {
	let configuration: HTTPClientConfiguration
	let urlSession: URLSession

	init(configuration: HTTPClientConfiguration, session: URLSession? = nil) {
		self.configuration = configuration

		if let session {
			urlSession = session
		} else {
			let config = URLSessionConfiguration.default
			config.timeoutIntervalForRequest = configuration.timeout
			config.timeoutIntervalForResource = configuration.timeout
			urlSession = URLSession(configuration: config)
		}
	}

	nonisolated func send<ResponseBody>(
		path: String,
		method: HTTPMethod,
		queryItems: [URLQueryItem]?,
		headers: [String: String]?,
		body: (some Encodable)?,
		responseType: ResponseBody.Type
	) async throws -> ResponseBody where ResponseBody: Decodable {
		fatalError()
	}

	nonisolated func stream(
		path: String,
		method: HTTPMethod,
		headers: [String: String],
		body: (some Encodable)?
	) -> AsyncThrowingStream<EventSource.Event, any Error> {
		if let body {
			try! print(body.jsonString(pretty: true))
		}

		let encodedBodyResult = Result<Data?, Error> {
			try body.map { try configuration.jsonEncoder.encode($0) }
		}

		// Explicit unbounded buffering ensures events are not dropped when
		// the consumer awaits long‑running work (e.g. tool execution).
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

					let (asyncBytes, response) = try await urlSession.bytes(for: request)

					let parser = EventSource.Parser()
					var rawData = ""

					for try await line in asyncBytes.lines {
						rawData += line + "\n"
						if line.hasPrefix("data:") {
							rawData += "\n"
						}
					}

					print(rawData)

					for byte in rawData.utf8 {
						await parser.consume(byte)
					}

					await parser.finish()

					while let event = await parser.getNextEvent() {
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

	private nonisolated func makeURL(path: String, queryItems: [URLQueryItem]?) throws -> URL {
		guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
			throw HTTPError.invalidURL
		}

		// Ensure single slash between base and path
		let trimmedBasePath = (components.path as NSString).standardizingPath
		let trimmedPath = ("/" + path).replacingOccurrences(of: "//", with: "/")
		components.path = (trimmedBasePath + "/" + trimmedPath).replacingOccurrences(of: "//", with: "/")
		components.queryItems = queryItems

		guard let url = components.url else { throw HTTPError.invalidURL }

		return url
	}
}

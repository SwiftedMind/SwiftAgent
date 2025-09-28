// By Dennis Müller

import EventSource
import Foundation
@testable import Internal
@testable import OpenAISession
@testable import SwiftAgent

extension OpenAIConfiguration {
	static func recording(apiKey: String) -> OpenAIConfiguration {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

		let decoder = JSONDecoder()

		let interceptors = HTTPClientInterceptors(
			prepareRequest: { request in
				request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
			},
			onUnauthorized: { _, _, _ in
				false
			},
		)

		let configuration = HTTPClientConfiguration(
			baseURL: URL(string: "https://api.openai.com")!,
			defaultHeaders: [:],
			timeout: 60,
			jsonEncoder: encoder,
			jsonDecoder: decoder,
			interceptors: interceptors,
		)

		return OpenAIConfiguration(httpClient: RecordingHTTPClient(configuration: configuration))
	}
}

final class RecordingHTTPClient: HTTPClient, @unchecked Sendable {
	private let configuration: HTTPClientConfiguration
	private let urlSession: URLSession
	private let recordingPrinter = HTTPRecordingPrinter()
	private let sequenceLock = NSLock()

	private var sequenceNumber: Int = 0

	init(configuration: HTTPClientConfiguration, session: URLSession? = nil) {
		self.configuration = configuration

		if let session {
			urlSession = session
		} else {
			let sessionConfiguration = URLSessionConfiguration.default
			sessionConfiguration.timeoutIntervalForRequest = configuration.timeout
			sessionConfiguration.timeoutIntervalForResource = configuration.timeout
			urlSession = URLSession(configuration: sessionConfiguration)
		}
	}

	func send<ResponseBody: Decodable>(
		path: String,
		method: HTTPMethod,
		queryItems: [URLQueryItem]?,
		headers: [String: String]?,
		body: (some Encodable)?,
		responseType _: ResponseBody.Type,
	) async throws -> ResponseBody {
		let currentSequenceNumber = nextSequenceNumber()
		let bodyEncoding = try encodeBodyIfNeeded(body)
		let request = try await makeRequest(
			path: path,
			method: method,
			queryItems: queryItems,
			headers: headers,
			bodyData: bodyEncoding.data,
			acceptHeader: "application/json",
		)

		let requestHeaders = request.allHTTPHeaderFields ?? [:]
		let requestContext = HTTPRecordingPrinter.RequestContext(
			sequenceNumber: currentSequenceNumber,
			method: method,
			url: request.url ?? configuration.baseURL,
			headers: requestHeaders,
			bodyDescription: bodyEncoding.logDescription,
		)
		recordingPrinter.printRequest(requestContext)

		let (data, response): (Data, URLResponse)
		do {
			(data, response) = try await urlSession.data(for: request)
		} catch {
			throw HTTPError.requestFailed(underlying: error)
		}

		guard let httpResponse = response as? HTTPURLResponse else {
			throw HTTPError.invalidResponse
		}

		let responseBodyDescription = recordingPrinter.makeJSONStringBlock(from: data)
		let responseContext = HTTPRecordingPrinter.ResponseContext(
			sequenceNumber: currentSequenceNumber,
			statusCode: httpResponse.statusCode,
			bodyDescription: responseBodyDescription,
		)
		recordingPrinter.printResponse(responseContext)

		guard (200..<300).contains(httpResponse.statusCode) else {
			throw HTTPError.unacceptableStatus(code: httpResponse.statusCode, data: data)
		}

		do {
			return try configuration.jsonDecoder.decode(ResponseBody.self, from: data)
		} catch {
			throw HTTPError.decodingFailed(underlying: error, data: data)
		}
	}

	func stream(
		path: String,
		method: HTTPMethod,
		headers: [String: String],
		body: (some Encodable)?,
	) -> AsyncThrowingStream<EventSource.Event, any Error> {
		let currentSequenceNumber = nextSequenceNumber()
		let bodyEncodingResult: Result<BodyEncoding, Error> = if let body {
			Result { try encodeBodyIfNeeded(body) }
		} else {
			.success(BodyEncoding())
		}

		return AsyncThrowingStream { continuation in
			let task = Task {
				var httpStatusCode: Int?
				var collectedBytes = Data()
				do {
					let bodyEncoding = try bodyEncodingResult.get()

					let request = try await self.makeRequest(
						path: path,
						method: method,
						queryItems: nil,
						headers: headers,
						bodyData: bodyEncoding.data,
						acceptHeader: "text/event-stream",
					)

					let requestHeaders = request.allHTTPHeaderFields ?? [:]
					let requestContext = HTTPRecordingPrinter.RequestContext(
						sequenceNumber: currentSequenceNumber,
						method: method,
						url: request.url ?? configuration.baseURL,
						headers: requestHeaders,
						bodyDescription: bodyEncoding.logDescription,
					)
					recordingPrinter.printRequest(requestContext)

					let (asyncBytes, response) = try await urlSession.bytes(for: request)

					guard let httpResponse = response as? HTTPURLResponse else {
						throw SSEError.invalidResponse
					}
					
					guard (200..<300).contains(httpResponse.statusCode) else {
						throw SSEError.badStatus(code: httpResponse.statusCode, body: nil)
					}

					httpStatusCode = httpResponse.statusCode

					let parser = EventSource.Parser()
					var iterator = asyncBytes.makeAsyncIterator()

					while let byte = try await iterator.next() {
						collectedBytes.append(byte)
						await parser.consume(byte)
					}

					await parser.finish()
					
					while let event = await parser.getNextEvent() {
						continuation.yield(event)
					}

					let rawStreamString = String(decoding: collectedBytes, as: UTF8.self)
					recordingPrinter.printStream(
						sequenceNumber: currentSequenceNumber,
						statusCode: httpStatusCode,
						rawEventPayload: rawStreamString,
					)

					continuation.finish()
				} catch {
					continuation.finish(throwing: error)
				}
			}

			continuation.onTermination = { @Sendable _ in
				task.cancel()
			}
		}
	}

	private func nextSequenceNumber() -> Int {
		sequenceLock.lock()
		defer { sequenceLock.unlock() }
		sequenceNumber += 1
		return sequenceNumber
	}

	private func encodeBodyIfNeeded(_ body: (some Encodable)?) throws -> BodyEncoding {
		guard let body else { return BodyEncoding() }

		let data = try configuration.jsonEncoder.encode(body)
		let description = recordingPrinter.makeJSONStringBlock(from: data)
		return BodyEncoding(data: data, logDescription: description)
	}

	private func makeRequest(
		path: String,
		method: HTTPMethod,
		queryItems: [URLQueryItem]?,
		headers: [String: String]?,
		bodyData: Data?,
		acceptHeader: String,
	) async throws -> URLRequest {
		let url = try makeURL(path: path, queryItems: queryItems)
		var request = URLRequest(url: url)
		request.httpMethod = method.rawValue
		request.setValue(acceptHeader, forHTTPHeaderField: "Accept")

		if let bodyData {
			request.httpBody = bodyData
			request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		}

		for (field, value) in configuration.defaultHeaders {
			request.setValue(value, forHTTPHeaderField: field)
		}

		if let headers {
			for (field, value) in headers {
				request.setValue(value, forHTTPHeaderField: field)
			}
		}

		if let prepareRequest = configuration.interceptors.prepareRequest {
			try await prepareRequest(&request)
		}

		return request
	}

	private func makeURL(path: String, queryItems: [URLQueryItem]?) throws -> URL {
		guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
			throw HTTPError.invalidURL
		}

		let trimmedBasePath = (components.path as NSString).standardizingPath
		let trimmedPath = ("/" + path).replacingOccurrences(of: "//", with: "/")
		components.path = (trimmedBasePath + "/" + trimmedPath).replacingOccurrences(of: "//", with: "/")
		components.queryItems = queryItems

		guard let url = components.url else { throw HTTPError.invalidURL }

		return url
	}
}

private struct BodyEncoding {
	var data: Data?
	var logDescription: String?

	init(data: Data? = nil, logDescription: String? = nil) {
		self.data = data
		self.logDescription = logDescription
	}
}

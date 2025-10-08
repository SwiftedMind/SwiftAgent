// By Dennis Müller

import EventSource
import Foundation
@testable import SwiftAgent

actor ReplayHTTPClient<RequestBodyType: Encodable & Sendable>: HTTPClient {
  enum ReplayError: Error, LocalizedError {
    case noRecordedResponsesRemaining
    case invalidUTF8RecordedResponse
    case invalidBodyType

    var errorDescription: String? {
      switch self {
      case .noRecordedResponsesRemaining:
        "Attempted to consume more recorded HTTP responses than were provided."
      case .invalidUTF8RecordedResponse:
        "Recorded HTTP response could not be converted to UTF-8 data."
      case .invalidBodyType:
        "Recorded HTTP request body is not of type RequestBodyType."
      }
    }
  }

  struct RecordedResponse: Sendable {
    var body: String
    var statusCode: Int
    var delay: Duration?

    init(body: String, statusCode: Int = 200, delay: Duration? = nil) {
      self.body = body
      self.statusCode = statusCode
      self.delay = delay
    }
  }

  struct Request: Sendable {
    var path: String
    var method: HTTPMethod
    var queryItems: [URLQueryItem]?
    var headers: [String: String]?
    var body: RequestBodyType
  }

  private var pendingRecordedResponses: [RecordedResponse]
  private(set) var recordedRequests: [Request] = []

  init(recordedResponses: [RecordedResponse]) {
    pendingRecordedResponses = recordedResponses
  }

  init(recordedResponse: RecordedResponse) {
    pendingRecordedResponses = [recordedResponse]
  }

  nonisolated func send<ResponseBody>(
    path: String,
    method: HTTPMethod,
    queryItems: [URLQueryItem]?,
    headers: [String: String]?,
    body: (some Encodable & Sendable)?,
    responseType: ResponseBody.Type,
  ) async throws -> ResponseBody where ResponseBody: Decodable {
    if let body = body as? RequestBodyType {
      await record(path: path, method: method, queryItems: queryItems, headers: headers, body: body)
    } else {
      throw ReplayError.invalidBodyType
    }

    let response = try await takeNextRecordedResponse()

    if let delay = response.delay {
      try await Task.sleep(for: delay)
      try Task.checkCancellation()
    }

    guard let data = response.body.data(using: .utf8) else {
      throw ReplayError.invalidUTF8RecordedResponse
    }
    guard (200..<300).contains(response.statusCode) else {
      throw HTTPError.unacceptableStatus(code: response.statusCode, data: data)
    }

    return try JSONDecoder().decode(ResponseBody.self, from: data)
  }

  nonisolated func stream(
    path: String,
    method: HTTPMethod,
    headers: [String: String],
    body: (some Encodable & Sendable)?,
  ) -> AsyncThrowingStream<EventSource.Event, any Error> {
    AsyncThrowingStream { continuation in
      let task = Task<Void, Never> {
        if let body = body as? RequestBodyType {
          await record(path: path, method: method, queryItems: nil, headers: headers, body: body)
        } else {
          continuation.finish(throwing: ReplayError.invalidBodyType)
          return
        }

        do {
          let response = try await takeNextRecordedResponse()
          guard let data = response.body.data(using: .utf8) else {
            throw ReplayError.invalidUTF8RecordedResponse
          }
          guard (200..<300).contains(response.statusCode) else {
            throw HTTPError.unacceptableStatus(code: response.statusCode, data: data)
          }

          for event in await parseEvents(from: response.body) {
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

  nonisolated func recordedRequests() async -> [Request] {
    await recordedRequests
  }
}

private extension ReplayHTTPClient {
  func takeNextRecordedResponse() throws -> RecordedResponse {
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

  func record(
    path: String,
    method: HTTPMethod,
    queryItems: [URLQueryItem]?,
    headers: [String: String]?,
    body: RequestBodyType,
  ) async {
    recordedRequests.append(
      Request(
        path: path,
        method: method,
        queryItems: queryItems,
        headers: headers,
        body: body,
      ),
    )
  }
}

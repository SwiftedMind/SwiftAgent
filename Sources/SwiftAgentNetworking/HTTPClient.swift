// By Dennis Müller

import Foundation

// MARK: - Public API

public protocol HTTPClient: Sendable {
  /// Sends an HTTP request with an Encodable JSON body and decodes the JSON response.
  @discardableResult
  func send<RequestBody: Encodable, ResponseBody: Decodable>(
    path: String,
    method: HTTPMethod,
    queryItems: [URLQueryItem]?,
    headers: [String: String]?,
    body: RequestBody?,
    responseType: ResponseBody.Type
  ) async throws -> ResponseBody
}

public enum HTTPMethod: String, Sendable {
  case get = "GET"
  case post = "POST"
  case put = "PUT"
  case delete = "DELETE"
  case patch = "PATCH"
}

/// Interceptors to customize request/response handling.
public struct HTTPClientInterceptors: Sendable {
  /// Allows adding auth headers or other customizations before the request is sent.
  public var prepareRequest: (@Sendable (inout URLRequest) async -> Void)?
  /// Called on 401 responses. Return true to indicate the request should be retried once (e.g. after refreshing auth).
  public var onUnauthorized: (@Sendable (_ response: HTTPURLResponse, _ data: Data?, _ originalRequest: URLRequest) async -> Bool)?

  public init(
    prepareRequest: (@Sendable (inout URLRequest) async -> Void)? = nil,
    onUnauthorized: (@Sendable (_ response: HTTPURLResponse, _ data: Data?, _ originalRequest: URLRequest) async -> Bool)? = nil
  ) {
    self.prepareRequest = prepareRequest
    self.onUnauthorized = onUnauthorized
  }
}

public struct HTTPClientConfiguration: Sendable {
  public var baseURL: URL
  public var defaultHeaders: [String: String]
  public var timeout: TimeInterval
  public var jsonEncoder: JSONEncoder
  public var jsonDecoder: JSONDecoder
  public var interceptors: HTTPClientInterceptors

  public init(
    baseURL: URL,
    defaultHeaders: [String: String] = [:],
    timeout: TimeInterval = 60,
    jsonEncoder: JSONEncoder = JSONEncoder(),
    jsonDecoder: JSONDecoder = JSONDecoder(),
    interceptors: HTTPClientInterceptors = .init()
  ) {
    self.baseURL = baseURL
    self.defaultHeaders = defaultHeaders
    self.timeout = timeout
    self.jsonEncoder = jsonEncoder
    self.jsonDecoder = jsonDecoder
    self.interceptors = interceptors
  }
}

public enum HTTPError: Error, Sendable, LocalizedError {
  case invalidURL
  case requestFailed(underlying: Error)
  case invalidResponse
  case unacceptableStatus(code: Int, data: Data?)
  case decodingFailed(underlying: Error, data: Data?)

  public var errorDescription: String? {
    switch self {
    case .invalidURL:
      return "Invalid URL"
    case let .requestFailed(underlying):
      return "Request failed: \(underlying.localizedDescription)"
    case .invalidResponse:
      return "Invalid response"
    case let .unacceptableStatus(code, _):
      return "Unacceptable status code: \(code)"
    case let .decodingFailed(underlying, _):
      return "Failed to decode response: \(underlying.localizedDescription)"
    }
  }
}

// MARK: - Implementation

public final class URLSessionHTTPClient: HTTPClient {
  private let configuration: HTTPClientConfiguration
  private let urlSession: URLSession

  public init(configuration: HTTPClientConfiguration, session: URLSession? = nil) {
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

  public func send<RequestBody: Encodable, ResponseBody: Decodable>(
    path: String,
    method: HTTPMethod,
    queryItems: [URLQueryItem]?,
    headers: [String: String]?,
    body: RequestBody?,
    responseType: ResponseBody.Type
  ) async throws -> ResponseBody {
    let url = try makeURL(path: path, queryItems: queryItems)
    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // Apply default headers then custom headers
    for (key, value) in configuration.defaultHeaders {
      request.setValue(value, forHTTPHeaderField: key)
    }
    if let headers { for (key, value) in headers {
      request.setValue(value, forHTTPHeaderField: key)
    } }

    if let body {
      request.httpBody = try configuration.jsonEncoder.encode(body)
    }

    // Allow caller to inject auth headers etc.
    if let prepare = configuration.interceptors.prepareRequest {
      await prepare(&request)
    }

    // Perform request, with one optional retry on 401
    let (data, response) = try await perform(request: request)
    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401,
       let onUnauthorized = configuration.interceptors.onUnauthorized {
      let shouldRetry = await onUnauthorized(httpResponse, data, request)
      if shouldRetry {
        var retryRequest = request
        // Allow re-preparing the request (e.g. with refreshed token)
        if let prepare = configuration.interceptors.prepareRequest {
          await prepare(&retryRequest)
        }
        let (retryData, retryResponse) = try await perform(request: retryRequest)
        return try decode(ResponseBody.self, data: retryData, response: retryResponse)
      }
    }

    return try decode(ResponseBody.self, data: data, response: response)
  }

  // MARK: - Helpers

  private func makeURL(path: String, queryItems: [URLQueryItem]?) throws -> URL {
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

  private func perform(request: URLRequest) async throws -> (Data, URLResponse) {
    do {
      return try await urlSession.data(for: request)
    } catch {
      throw HTTPError.requestFailed(underlying: error)
    }
  }

  private func decode<T: Decodable>(_ type: T.Type, data: Data, response: URLResponse) throws -> T {
    guard let http = response as? HTTPURLResponse else { throw HTTPError.invalidResponse }
    guard (200..<300).contains(http.statusCode) else {
      throw HTTPError.unacceptableStatus(code: http.statusCode, data: data)
    }

    do {
      return try configuration.jsonDecoder.decode(type, from: data)
    } catch {
      throw HTTPError.decodingFailed(underlying: error, data: data)
    }
  }
}

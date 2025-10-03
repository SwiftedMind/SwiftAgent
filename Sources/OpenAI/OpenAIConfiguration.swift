// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import SwiftAgent

public struct OpenAIConfiguration: AdapterConfiguration {
	var httpClient: HTTPClient

	public init(httpClient: HTTPClient) {
		self.httpClient = httpClient
	}

	/// Convenience builder for calling OpenAI directly with an API key.
	///
	/// This is intended for prototyping only. Shipping an API key inside an app binary is
	/// insecure and should be avoided in production. Prefer ``proxy(through:)`` with
	/// short‑lived, backend‑issued tokens that are scoped to a single agent turn.
	public static func direct(apiKey: String) -> OpenAIConfiguration {
		let encoder = JSONEncoder()

		// .sortedKeys is important to enable reliable cache hits!
		encoder.outputFormatting = .sortedKeys

		let decoder = JSONDecoder()
		// Keep defaults; OpenAI models define their own coding keys

		let interceptors = HTTPClientInterceptors(
			prepareRequest: { request in
//				request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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

		return OpenAIConfiguration(httpClient: URLSessionHTTPClient(configuration: config))
	}

	/// Configures the adapter to send all requests through your own proxy backend.
	///
	/// The proxy approach is the recommended, secure way to use the SDK in apps. Your backend
	/// issues a short‑lived token (for example, for a single agent turn) and the app attaches it
	/// to requests. This way, api keys never ship in the app bundle and communication with the backend stays secure.
	///
	/// This configuration reads the token from the internal task‑local authorization context that
	/// you set via ``LanguageModelProvider/withAuthorization(token:refresh:perform:)``. If the proxy responds
	/// with `401 Unauthorized` and a refresh closure was provided to `withAuthorization`, the SDK will
	/// obtain a new token from that closure and retry the request once.
	///
	/// - Parameter baseURL: The base `URL` of your proxy backend.
	/// - Returns: A configured `OpenAIConfiguration` instance.
	///
	/// ## Example: Recommended Proxy + Per‑Turn Token
	///
	/// ```swift
	/// let configuration = OpenAIConfiguration.proxy(through: URL(string: "https://api.your‑backend.com")!)
	/// let session = LanguageModelProvider.openAI(
	///   tools: [WeatherTool(), CalculatorTool()],
	///   instructions: "You are a helpful assistant.",
	///   configuration: configuration
	/// )
	///
	/// // Obtain a short‑lived token for this agent turn from your backend
	/// let token = try await backend.issueTurnToken(for: userId)
	///
	/// // Run the turn under this authorization context
	/// let response = try await session.withAuthorization(token: token) {
	///   try await session.respond(to: "Help me plan a weekend in Berlin.")
	/// }
	/// print(response.content)
	/// ```
	public static func proxy(through baseURL: URL) -> OpenAIConfiguration {
		let encoder = JSONEncoder()

		// .sortedKeys is important to enable reliable cache hits!
		encoder.outputFormatting = .sortedKeys

		let decoder = JSONDecoder()
		// Keep defaults; OpenAI models define their own coding keys

		let interceptors = HTTPClientInterceptors(
			prepareRequest: { request in
				guard let context = AuthorizationContext.current else {
					preconditionFailure("OpenAIConfiguration.proxy(through:) requires an authorization context.")
				}

				await request.setValue("Bearer \(context.bearerToken)", forHTTPHeaderField: "Authorization")
			},
			onUnauthorized: { _, _, _ in
				guard let context = AuthorizationContext.current, let refreshToken = await context.refreshToken else {
					return false
				}
				guard let newToken = try? await refreshToken() else {
					return false
				}

				await context.setBearerToken(newToken)
				return true
			}
		)

		let config = HTTPClientConfiguration(
			baseURL: baseURL,
			defaultHeaders: [:],
			timeout: 60,
			jsonEncoder: encoder,
			jsonDecoder: decoder,
			interceptors: interceptors
		)

		return OpenAIConfiguration(httpClient: URLSessionHTTPClient(configuration: config))
	}
}

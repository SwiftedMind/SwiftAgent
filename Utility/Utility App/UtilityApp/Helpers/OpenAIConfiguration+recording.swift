// By Dennis Müller

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
			}
		)

		let configuration = HTTPClientConfiguration(
			baseURL: URL(string: "https://api.openai.com")!,
			defaultHeaders: [:],
			timeout: 60,
			jsonEncoder: encoder,
			jsonDecoder: decoder,
			interceptors: interceptors
		)

		return OpenAIConfiguration(httpClient: RecordingHTTPClient(configuration: configuration))
	}
}

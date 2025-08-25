// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public struct OpenAIConfiguration: AdapterConfiguration {
  var httpClient: HTTPClient
  var responsesPath: String

  init(httpClient: HTTPClient, responsesPath: String = "/v1/responses") {
    self.httpClient = httpClient
    self.responsesPath = responsesPath
  }

  /// Convenience builder for calling OpenAI directly with an API key.
  /// Users can alternatively point `baseURL` to their own backend and omit the apiKey.
  public static func direct(
    apiKey: String,
    baseURL: URL = URL(string: "https://api.openai.com")!,
    responsesPath: String = "/v1/responses"
  ) -> OpenAIConfiguration {
    let encoder = JSONEncoder()
    
    // .sortedKeys is important to enable reliable cache hits!
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
      baseURL: baseURL,
      defaultHeaders: [:],
      timeout: 60,
      jsonEncoder: encoder,
      jsonDecoder: decoder,
      interceptors: interceptors
    )

    return OpenAIConfiguration(httpClient: URLSessionHTTPClient(configuration: config), responsesPath: responsesPath)
  }
}

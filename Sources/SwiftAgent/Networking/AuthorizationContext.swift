// By Dennis Müller

/// Internal, task‑local authorization context used by proxy configurations.
///
/// ``AuthorizationContext`` is an internal actor that carries the current access token for
/// a single logical unit of work, typically one agent turn. It is not meant to be used
/// directly by applications. Instead, call ``LanguageModelProvider/withAuthorization(token:refresh:perform:)``
/// which sets this context using a `@TaskLocal` value so that adapter configurations can
/// read it and attach the token to outbound requests.
///
/// Adapters like ``OpenAIConfiguration/proxy(through:)`` read this context on each request.
/// If a request returns `401 Unauthorized` and a `refreshToken` closure is available, the
/// adapter may invoke it to obtain a new token and retry once.
package actor AuthorizationContext {
  @TaskLocal package static var current: AuthorizationContext?

  package var bearerToken: String
  package let refreshToken: (@Sendable () async throws -> String)?

  package init(bearerToken: String, refreshToken: (@Sendable () async throws -> String)? = nil) {
    self.bearerToken = bearerToken
    self.refreshToken = refreshToken
  }

  package func setBearerToken(_ token: String) {
    bearerToken = token
  }
}

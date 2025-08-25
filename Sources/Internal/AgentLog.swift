// By Dennis Müller

import Foundation
import OSLog

/// Centralized, human-friendly logging for agent runs and tool calls.
///
/// Uses the SDK's `Logger.main` instance to emit concise, readable console output
/// with consistent formatting. JSON payloads are pretty-printed when possible.
package enum AgentLog {
  /// Logs the start of an agent run.
  package static func start(model: String, toolNames: [String], promptPreview: String?) {
    let tools = toolNames.isEmpty ? "-" : toolNames.joined(separator: ", ")
    let preview = promptPreview.map { "\($0.prefix(180))" } ?? "-"
    Logger.main.info(
      "🟢 \(String(localized: "Agent start")) — model=\(model, privacy: .public) | tools=\(tools, privacy: .public) | prompt=\(preview, privacy: .public)"
    )
  }

  /// Logs that the provider is requesting the next response step.
  package static func stepRequest(step: Int) {
    Logger.main.debug("↗️ \(String(localized: "Request step")) #\(step, privacy: .public)")
  }

  /// Logs a plain message output from the model.
  package static func outputMessage(text: String, status: String) {
    let preview = text.trimmingCharacters(in: .whitespacesAndNewlines)
    Logger.main.info(
      "💬 \(String(localized: "Output")) — status=\(status, privacy: .public)\n\(preview, privacy: .public)"
    )
  }

  /// Logs a structured (JSON) output from the model.
  package static func outputStructured(json: String, status: String) {
    Logger.main.info(
      "📦 \(String(localized: "Structured output")) — status=\(status, privacy: .public)\n\(pretty(json: json), privacy: .public)"
    )
  }

  /// Logs that a tool call was requested by the model.
  package static func toolCall(name: String, callId: String, argumentsJSON: String) {
    Logger.main.info(
      "🛠️ \(String(localized: "Tool call")) — \(name, privacy: .public) [\(callId, privacy: .public)]\nargs:\n\(pretty(json: argumentsJSON), privacy: .public)"
    )
  }

  /// Logs tool output after the tool completed successfully.
  package static func toolOutput(name: String, callId: String, outputJSONOrText: String) {
    let body = pretty(json: outputJSONOrText)
    Logger.main.info(
      "📤 \(String(localized: "Tool output")) — \(name, privacy: .public) [\(callId, privacy: .public)]\n\(body, privacy: .public)"
    )
  }

  /// Logs a reasoning summary if available.
  package static func reasoning(summary: [String]) {
    guard !summary.isEmpty else { return }

    let joined = summary.joined(separator: "\n• ")
    Logger.main.debug(
      "🧠 \(String(localized: "Reasoning"))\n• \(joined, privacy: .public)"
    )
  }

  /// Logs that the run finished.
  package static func finish() {
    Logger.main.info("✅ \(String(localized: "Finished"))")
  }

  /// Logs token usage accounting.
  package static func tokenUsage(
    inputTokens: Int?,
    outputTokens: Int?,
    totalTokens: Int?,
    cachedTokens: Int?,
    reasoningTokens: Int?
  ) {
    let input = inputTokens.map(String.init) ?? "-"
    let output = outputTokens.map(String.init) ?? "-"
    let total = totalTokens.map(String.init) ?? "-"
    let cached = cachedTokens.map(String.init) ?? "-"
    let reasoning = reasoningTokens.map(String.init) ?? "-"

    Logger.main.info(
      "🧮 \(String(localized: "Token usage")) — input=\(input, privacy: .public) | output=\(output, privacy: .public) | total=\(total, privacy: .public) | cached=\(cached, privacy: .public) | reasoning=\(reasoning, privacy: .public)"
    )
  }

  /// Logs an error during the run.
  package static func error(_ error: any Error, context: String? = nil) {
    let ctx = context ?? "-"
    let errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    Logger.main.error(
      "⛔️ \(String(localized: "Error")) — \(ctx, privacy: .public): \(errorMessage, privacy: .public)"
    )
  }

  // MARK: - General Logging

  /// Logs a debug message with optional context.
  package static func debug(_ message: String, context: String? = nil) {
    let formatted = context.map { "🔍 \($0) — \(message)" } ?? "🔍 \(message)"
    Logger.main.debug("\(formatted, privacy: .public)")
  }

  /// Logs an informational message with optional context.
  package static func info(_ message: String, context: String? = nil) {
    let formatted = context.map { "ℹ️ \($0) — \(message)" } ?? "ℹ️ \(message)"
    Logger.main.info("\(formatted, privacy: .public)")
  }

  /// Logs a success message with optional context.
  package static func success(_ message: String, context: String? = nil) {
    let formatted = context.map { "✅ \($0) — \(message)" } ?? "✅ \(message)"
    Logger.main.info("\(formatted, privacy: .public)")
  }

  /// Logs a warning message with optional context.
  package static func warning(_ message: String, context: String? = nil) {
    let formatted = context.map { "⚠️ \($0) — \(message)" } ?? "⚠️ \(message)"
    Logger.main.warning("\(formatted, privacy: .public)")
  }

  /// Pretty-prints a JSON string if possible, otherwise returns the input.
  package static func pretty(json: String) -> String {
    guard let data = json.data(using: .utf8) else { return json }

    do {
      let object = try JSONSerialization.jsonObject(with: data)
      let pretty = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
      return String(data: pretty, encoding: .utf8) ?? json
    } catch {
      return json
    }
  }
}

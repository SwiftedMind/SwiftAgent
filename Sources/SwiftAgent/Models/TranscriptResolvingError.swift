// By Dennis Müller

import Foundation

/// Errors thrown while materializing a transcript into schema-backed types.
///
/// When ``Transcript/resolved(using:)`` encounters payloads it cannot interpret with the supplied
/// ``SessionSchema``, the resolver surfaces one of these errors. Each case carries context you can
/// surface in logs or UI to explain which element failed and why.
public enum TranscriptResolvingError: Error, LocalizedError, Sendable, Equatable {
  /// Prompt reconstruction failed, usually because grounding payloads did not match the schema.
  case prompt(PromptResolution)

  /// Tool run could not be resolved into the schema-defined tool type.
  case toolRun(ToolRunResolution)

  public var errorDescription: String? {
    switch self {
    case let .prompt(resolution):
      resolution.errorDescription
    case let .toolRun(resolution):
      resolution.errorDescription
    }
  }

  /// Context describing why a prompt failed to resolve.
  public enum PromptResolution: Error, LocalizedError, Sendable, Equatable {
    /// A grounding value could not be converted into the schema's declared type.
    case groundingResolutionFailed(description: String)

    public var errorDescription: String? {
      switch self {
      case let .groundingResolutionFailed(description):
        "Prompt grounding resolution failed: \(description)"
      }
    }
  }

  /// Context describing why a tool run failed to resolve.
  public enum ToolRunResolution: Error, LocalizedError, Sendable, Equatable {
    /// The transcript referenced a tool name not registered in the session schema.
    case unknownTool(name: String)

    /// The tool was known but its arguments or output could not be converted into typed values.
    case resolutionFailed(description: String)

    public var errorDescription: String? {
      switch self {
      case let .unknownTool(name):
        "Tool run failed: unknown tool named \(name)"
      case let .resolutionFailed(description):
        "Tool run failed: \(description)"
      }
    }
  }
}

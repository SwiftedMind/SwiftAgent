// By Dennis Müller

import Foundation

/// Integers render using their textual description.
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Int: PromptRepresentable {}

/// Bool render using their textual description.
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Bool: PromptRepresentable {}

/// Doubles render using their textual description.
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Double: PromptRepresentable {}

/// UUIDs render using their canonical `uuidString`.
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension UUID: PromptRepresentable {
  public var promptRepresentation: Prompt {
    uuidString
  }
}

/// URLs render using their absolute string representation.
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension URL: PromptRepresentable {
  public var promptRepresentation: Prompt {
    absoluteString
  }
}

/// Dates render in ISO‑8601 format using modern `Foundation` formatting.
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Date: PromptRepresentable {
  public var promptRepresentation: Prompt {
    // Use modern Foundation formatting for a deterministic ISO 8601 output.
    formatted(.iso8601)
  }
}

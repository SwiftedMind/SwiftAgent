// By Dennis Müller

import Foundation
import Internal

/// Internal stream updates emitted by adapters while generating.
///
/// These updates are translated by `LanguageModelProvider` into public-facing state
/// (e.g., transcript updates and responses). While public for type exposure,
/// they are considered an SDK-internal mechanism.
public enum AdapterUpdate: Sendable, Equatable {
	/// A transcript entry produced during generation (reasoning, tool calls, outputs, responses...).
	case transcript(Transcript.Entry)

	/// Token usage information for a request/step. Optional today; may be provided by adapters.
	case tokenUsage(TokenUsage)
}

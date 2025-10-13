// By Dennis Müller

import MacroTesting
import SwiftAgentMacros
import SwiftSyntaxMacros
import Testing

private struct Transcript {}

@Suite("@_LanguageModelProviderObserved expansion")
struct LanguageModelProviderObservedMacroTests {
  @Test("Basic")
  func expansion_matches_expected_output() {
    assertMacro(
      ["_LanguageModelProviderObserved": LanguageModelProviderObservedMacro.self],
      indentationWidth: .spaces(2)
    ) {
      #"""
      @MainActor @_LanguageModelProviderObserved(initialValue: Transcript()) fileprivate var transcript: Transcript
      """#
    } expansion: {
      #"""
      @MainActor fileprivate var transcript: Transcript {
        get {
          access(keyPath: \.transcript)
          return _transcript
        }
        set {
          guard shouldNotifyObservers(_transcript, newValue) else {
            _transcript = newValue
            return
          }

          withMutation(keyPath: \.transcript) {
            _transcript = newValue
          }
        }
        _modify {
          access(keyPath: \.transcript)
          _$observationRegistrar.willSet(self, keyPath: \.transcript)
          defer {
            _$observationRegistrar.didSet(self, keyPath: \.transcript)
          }
          yield &_transcript
        }
      }

      @MainActor private var _transcript: Transcript = Transcript()
      """#
    }
  }
}

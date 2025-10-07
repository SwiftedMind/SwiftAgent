// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public protocol ResolvableStructuredOutput<Provider>: Sendable, Equatable {
  associatedtype Schema: Generable
  associatedtype Provider: LanguageModelProvider
  static var name: String { get }
  static func resolve(_ structuredOutput: StructuredOutput<Self>) -> Provider.ResolvedStructuredOutput
}

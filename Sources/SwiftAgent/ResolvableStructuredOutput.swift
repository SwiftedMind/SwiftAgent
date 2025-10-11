// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public protocol ResolvableStructuredOutput<Provider>: Sendable, Equatable {
  associatedtype Base: StructuredOutput
  associatedtype Provider: LanguageModelProvider
  static var name: String { get }
  static func resolve(_ structuredOutput: ContentGeneration<Self>) -> Provider.ResolvedStructuredOutput
}

public extension ResolvableStructuredOutput {
  static var name: String { Base.name }
}

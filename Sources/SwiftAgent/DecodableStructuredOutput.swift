// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public protocol DecodableStructuredOutput<Provider>: Sendable, Equatable {
  associatedtype Base: StructuredOutput
  associatedtype Provider: LanguageModelProvider
  static var name: String { get }
  static func decode(_ structuredOutput: StructuredOutputUpdate<Self>) -> Provider.DecodedStructuredOutput
}

public extension DecodableStructuredOutput {
  static var name: String { Base.name }
}

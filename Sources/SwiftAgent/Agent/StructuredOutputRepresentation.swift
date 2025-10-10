// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public struct StructuredOutputRepresentation<Provider: LanguageModelProvider, Schema: Generable>: Sendable, Equatable {
  public let name: String

  public var schemaType: Schema.Type {
    Schema.self
  }

  public init(_ name: String) { self.name = name }
}

// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public protocol StructuredOutputRepresentable: Sendable, Equatable {
  associatedtype Provider: LanguageModelProvider
  associatedtype Schema: Generable
  var name: String { get }
}

public struct StructuredOutputRepresentation<
  Provider: LanguageModelProvider,
  Schema: Generable,
>: StructuredOutputRepresentable {
  public typealias Provider = Provider
  public typealias Schema = Schema
  public let name: String

  public var schemaType: Schema.Type {
    Schema.self
  }

  public init(_ name: String) { self.name = name }
}

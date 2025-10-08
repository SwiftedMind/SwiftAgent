// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public protocol StructuredOutputRepresentable: Sendable, Equatable {
  associatedtype Provider: LanguageModelProvider
  associatedtype Schema: Generable
  var name: String { get }
}

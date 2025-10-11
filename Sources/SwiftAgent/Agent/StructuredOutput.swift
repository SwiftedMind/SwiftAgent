// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public protocol StructuredOutput<Schema>: Sendable {
  associatedtype Schema: Generable
  static var name: String { get }
}

// TODO: Is this the best solution?
extension String: StructuredOutput {
  public typealias Schema = Self
  public static var name: String { "String" }
}

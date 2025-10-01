// By Dennis Müller

import Foundation

// MARK: - Errors

enum MacroError: Error, CustomStringConvertible {
  case notAProperty
  case mustBeLet
  case noBinding
  case invalidPattern
  case missingTypeAnnotation
  case onlyApplicableToClass
  case missingProvider
  case invalidProvider

  var description: String {
    switch self {
    case .notAProperty:
      "@ResolvableTool can only be applied to properties"
    case .mustBeLet:
      "@ResolvableTool properties must be declared with 'let'"
    case .noBinding:
      "Property has no binding"
    case .invalidPattern:
      "Property pattern must be a simple identifier"
    case .missingTypeAnnotation:
      "@ResolvableTool properties must have explicit type annotations"
    case .onlyApplicableToClass:
      "@SwiftAgentSession can only be applied to a class"
    case .missingProvider:
      "@SwiftAgentSession requires a 'provider' argument"
    case .invalidProvider:
      "Invalid provider. Valid providers: .openAI"
    }
  }
}

// MARK: - Helpers

extension String {
  func capitalizedFirstLetter() -> String {
    prefix(1).uppercased() + dropFirst()
  }
}

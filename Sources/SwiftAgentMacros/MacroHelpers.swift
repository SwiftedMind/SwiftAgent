// By Dennis Müller

import Foundation

// MARK: - Errors

enum MacroError: Error, CustomStringConvertible {
	case notAProperty
	case mustBeVar
	case noBinding
	case invalidPattern
	case missingTypeAnnotation
	case cannotInferType
	case onlyApplicableToClass
	case missingProvider
	case invalidProvider
	case missingGroundingType
	case invalidGroundingAttribute

	var description: String {
		switch self {
		case .notAProperty:
			"@Tool can only be applied to stored properties"
		case .mustBeVar:
			"Macro-managed properties must be declared with 'var'"
		case .noBinding:
			"Property has no binding"
		case .invalidPattern:
			"Macro-managed properties must use a simple identifier pattern"
		case .missingTypeAnnotation:
			"@Tool properties must have explicit type annotations"
		case .cannotInferType:
			"@Tool cannot infer type from this initializer. Provide an explicit type annotation or use a simple initializer like 'Type()'"
		case .onlyApplicableToClass:
			"@LanguageModelProvider can only be applied to a class"
		case .missingProvider:
			"@LanguageModelProvider requires a 'for' argument"
		case .invalidProvider:
			"Invalid provider. Valid providers: .openAI"
		case .missingGroundingType:
			"@Grounding requires a type argument like 'Type.self'"
		case .invalidGroundingAttribute:
			"Invalid @Grounding attribute configuration"
		}
	}
}

// MARK: - Helpers

extension String {
	func capitalizedFirstLetter() -> String {
		prefix(1).uppercased() + dropFirst()
	}
}

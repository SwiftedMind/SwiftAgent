// By Dennis Müller

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension LanguageModelProviderMacro {
  /// Reads the provider argument from the macro attribute, if one was supplied.
  static func extractProvider(from attribute: AttributeSyntax) throws -> Provider {
    guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
          let providerArgument = arguments.first
    else {
      throw MacroError.missingProvider(node: Syntax(attribute)).asDiagnosticsError()
    }

    if let label = providerArgument.label, label.text != "for" {
      throw MacroError.invalidProvider(node: Syntax(providerArgument)).asDiagnosticsError()
    }
    guard let memberAccess = providerArgument.expression.as(MemberAccessExprSyntax.self) else {
      throw MacroError.invalidProvider(node: Syntax(providerArgument.expression)).asDiagnosticsError()
    }

    let providerName = memberAccess.declName.baseName.text

    guard let provider = Provider(rawValue: providerName) else {
      throw MacroError.invalidProvider(node: Syntax(memberAccess)).asDiagnosticsError()
    }

    return provider
  }

  /// Finds every `@Tool` property on the session declaration and records essential metadata.
  static func extractToolProperties(from classDeclaration: ClassDeclSyntax) throws -> [ToolProperty] {
    try classDeclaration.memberBlock.members.compactMap { member in
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self) else {
        return nil
      }
      guard variableDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
        throw MacroError.mustBeVar(node: Syntax(variableDecl.bindingSpecifier)).asDiagnosticsError()
      }

      let hasToolAttribute = attributeList(
        variableDecl.attributes,
        containsAttributeNamed: "Tool",
      )

      guard hasToolAttribute else {
        return nil
      }
      guard let binding = variableDecl.bindings.first else {
        throw MacroError.noBinding(node: Syntax(variableDecl)).asDiagnosticsError()
      }
      guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
        throw MacroError.invalidPattern(node: Syntax(binding.pattern)).asDiagnosticsError()
      }

      let typeName: String
      if let typeAnnotation = binding.typeAnnotation {
        typeName = typeAnnotation.type.trimmedDescription
      } else if let initializer = binding.initializer {
        if let functionCall = initializer.value.as(FunctionCallExprSyntax.self) {
          typeName = functionCall.calledExpression.trimmedDescription
        } else {
          throw MacroError.cannotInferType(node: Syntax(initializer.value)).asDiagnosticsError()
        }
      } else {
        throw MacroError.missingTypeAnnotation(node: Syntax(binding.pattern)).asDiagnosticsError()
      }

      return ToolProperty(
        identifier: identifierPattern.identifier,
        typeName: typeName,
        hasInitializer: binding.initializer != nil,
      )
    }
  }

  /// Collects `@Grounding` declarations to drive `DecodedGrounding` synthesis.
  static func extractGroundingProperties(from classDeclaration: ClassDeclSyntax) throws -> [GroundingProperty] {
    try classDeclaration.memberBlock.members.compactMap { member in
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self) else {
        return nil
      }
      guard let groundingAttribute = attribute(named: "Grounding", in: variableDecl.attributes) else {
        return nil
      }
      guard variableDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
        throw MacroError.mustBeVar(node: Syntax(variableDecl.bindingSpecifier)).asDiagnosticsError()
      }
      guard let binding = variableDecl.bindings.first else {
        throw MacroError.noBinding(node: Syntax(variableDecl)).asDiagnosticsError()
      }
      guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
        throw MacroError.invalidPattern(node: Syntax(binding.pattern)).asDiagnosticsError()
      }

      let typeName = try extractGroundingTypeName(from: groundingAttribute)

      return GroundingProperty(
        identifier: identifierPattern.identifier,
        typeName: typeName,
      )
    }
  }

  /// Collects `@StructuredOutput` declarations to drive typed response synthesis.
  static func extractStructuredOutputProperties(from classDeclaration: ClassDeclSyntax) throws
    -> [StructuredOutputProperty] {
    try classDeclaration.memberBlock.members.compactMap { member in
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self) else {
        return nil
      }
      guard let structuredOutputAttribute = attribute(named: "StructuredOutput", in: variableDecl.attributes) else {
        return nil
      }
      guard variableDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
        throw MacroError.mustBeVar(node: Syntax(variableDecl.bindingSpecifier)).asDiagnosticsError()
      }
      guard let binding = variableDecl.bindings.first else {
        throw MacroError.noBinding(node: Syntax(variableDecl)).asDiagnosticsError()
      }
      guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
        throw MacroError.invalidPattern(node: Syntax(binding.pattern)).asDiagnosticsError()
      }

      let typeName = try extractGroundingTypeName(from: structuredOutputAttribute)

      return StructuredOutputProperty(
        identifier: identifierPattern.identifier,
        typeName: typeName,
      )
    }
  }

  /// Pulls the concrete type referenced by a `@Grounding` attribute argument.
  static func extractGroundingTypeName(from attribute: AttributeSyntax) throws -> String {
    guard let arguments = attribute.arguments else {
      throw MacroError.missingGroundingType(node: Syntax(attribute)).asDiagnosticsError()
    }
    guard case let .argumentList(argumentList) = arguments else {
      throw MacroError.invalidGroundingAttribute(node: Syntax(attribute)).asDiagnosticsError()
    }
    guard argumentList.count == 1, let argument = argumentList.first else {
      throw MacroError.missingGroundingType(node: Syntax(attribute)).asDiagnosticsError()
    }
    guard argument.label == nil else {
      throw MacroError.invalidGroundingAttribute(node: Syntax(attribute)).asDiagnosticsError()
    }

    let content = argument.expression.trimmedDescription

    guard content.hasSuffix(".self") else {
      throw MacroError.missingGroundingType(node: Syntax(attribute)).asDiagnosticsError()
    }

    let typeName = content.dropLast(".self".count)

    guard !typeName.isEmpty else {
      throw MacroError.missingGroundingType(node: Syntax(attribute)).asDiagnosticsError()
    }

    return String(typeName)
  }
}

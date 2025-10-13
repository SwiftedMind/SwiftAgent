// By Dennis Müller

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Property macro that synthesizes Observation storage and accessors for provider-managed members.
public struct LanguageModelProviderObservedMacro: PeerMacro, AccessorMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext,
  ) throws -> [DeclSyntax] {
    guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
      return []
    }
    guard variableDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
      throw MacroError.mustBeVar(node: Syntax(variableDecl)).asDiagnosticsError()
    }
    guard let binding = variableDecl.bindings.first else {
      throw MacroError.noBinding(node: Syntax(variableDecl)).asDiagnosticsError()
    }
    guard variableDecl.bindings.count == 1 else {
      throw MacroError.invalidPattern(node: Syntax(binding.pattern)).asDiagnosticsError()
    }
    guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
      throw MacroError.invalidPattern(node: Syntax(binding.pattern)).asDiagnosticsError()
    }
    guard let typeAnnotation = binding.typeAnnotation else {
      throw MacroError.missingTypeAnnotation(node: Syntax(binding.pattern)).asDiagnosticsError()
    }

    if binding.initializer != nil {
      throw MacroError.observedPropertyProvidesInitializer(
        node: Syntax(binding.initializer!),
      ).asDiagnosticsError()
    }

    let initialValueExpression = try extractInitialValueExpression(from: node)
    let propertyName = identifierPattern.identifier.text
    let type = typeAnnotation.type.trimmed

    let attributePrefix = attributeText(excludingObservedMacro: variableDecl.attributes)
    let storedProperty: DeclSyntax =
      """
      \(raw: attributePrefix)private var _\(raw: propertyName): \(type) = \(initialValueExpression)
      """

    return [storedProperty]
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext,
  ) throws -> [AccessorDeclSyntax] {
    guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
      return []
    }
    guard let binding = variableDecl.bindings.first,
          let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self)
    else {
      throw MacroError.invalidPattern(node: Syntax(declaration)).asDiagnosticsError()
    }

    let propertyName = identifierPattern.identifier.text
    let keyPath = "\\.\(propertyName)"

    return [
      """
      get {
        access(keyPath: \(raw: keyPath))
        return _\(raw: propertyName)
      }
      """,
      """
      set {
        guard shouldNotifyObservers(_\(raw: propertyName), newValue) else {
          _\(raw: propertyName) = newValue
          return
        }

        withMutation(keyPath: \(raw: keyPath)) {
          _\(raw: propertyName) = newValue
        }
      }
      """,
      """
      _modify {
        access(keyPath: \(raw: keyPath))
        _$observationRegistrar.willSet(self, keyPath: \(raw: keyPath))
        defer {
          _$observationRegistrar.didSet(self, keyPath: \(raw: keyPath))
        }
        yield &_\(raw: propertyName)
      }
      """,
    ]
  }
}

extension LanguageModelProviderObservedMacro {
  /// Extracts the initializer expression from the macro attribute.
  private static func extractInitialValueExpression(
    from attribute: AttributeSyntax,
  ) throws -> ExprSyntax {
    guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
          let firstArgument = arguments.first
    else {
      throw MacroError.missingObservedInitialValue(node: Syntax(attribute)).asDiagnosticsError()
    }

    if let label = firstArgument.label, label.text != "initialValue" {
      throw MacroError.missingObservedInitialValue(node: Syntax(firstArgument)).asDiagnosticsError()
    }

    return firstArgument.expression.trimmed
  }

  /// Builds the attribute text to copy over to the stored property, excluding the observed macro itself.
  private static func attributeText(excludingObservedMacro attributes: AttributeListSyntax?) -> String {
    guard let attributes, !attributes.isEmpty else {
      return ""
    }

    let retainedAttributes = attributes.compactMap { attribute -> String? in
      guard let attribute = attribute.as(AttributeSyntax.self) else {
        return attribute.trimmedDescription
      }

      if attribute.attributeName.trimmedDescription == "_LanguageModelProviderObserved" {
        return nil
      }

      return attribute.trimmedDescription
    }

    guard !retainedAttributes.isEmpty else {
      return ""
    }

    return retainedAttributes.joined(separator: " ") + " "
  }
}

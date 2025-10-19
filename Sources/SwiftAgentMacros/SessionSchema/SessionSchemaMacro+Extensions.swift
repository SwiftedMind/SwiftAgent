// By Dennis Müller

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension SessionSchemaMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext,
  ) throws -> [ExtensionDeclSyntax] {
    guard let structDeclaration = declaration.as(StructDeclSyntax.self) else {
      throw MacroError.onlyApplicableToStruct(node: Syntax(node)).asDiagnosticsError()
    }

    var extensions: [ExtensionDeclSyntax] = []

    let languageModelExtension: DeclSyntax =
      """
      extension \(type.trimmed): LanguageModelSessionSchema {}
      """

    if let extensionSyntax = languageModelExtension.as(ExtensionDeclSyntax.self) {
      extensions.append(extensionSyntax)
    }

    let groundingProperties = try extractGroundingProperties(from: structDeclaration)
    if !groundingProperties.isEmpty {
      let groundingExtension: DeclSyntax =
        """
        extension \(type.trimmed): GroundingSupportingSchema {}
        """

      if let extensionSyntax = groundingExtension.as(ExtensionDeclSyntax.self) {
        extensions.append(extensionSyntax)
      }
    }

    return extensions
  }
}

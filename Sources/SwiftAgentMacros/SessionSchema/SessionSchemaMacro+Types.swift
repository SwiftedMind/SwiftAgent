// By Dennis Müller

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension SessionSchemaMacro {
  /// Captures information about a `@Tool` property declared on the session schema.
  struct ToolProperty {
    let identifier: TokenSyntax
    let typeName: String
    let hasInitializer: Bool
  }

  /// Captures information about a `@Grounding` property declared on the session schema.
  struct GroundingProperty {
    let identifier: TokenSyntax
    let typeName: String
  }

  /// Captures information about a `@StructuredOutput` property declared on the session schema.
  struct StructuredOutputProperty {
    let identifier: TokenSyntax
    let typeName: String
  }

  /// Checks whether an attribute list already contains an attribute with the provided base name.
  static func attributeList(
    _ attributes: AttributeListSyntax?,
    containsAttributeNamed name: String,
  ) -> Bool {
    guard let attributes else {
      return false
    }

    return attributes.contains { attribute in
      guard let attributeSyntax = attribute.as(AttributeSyntax.self) else {
        return false
      }

      return attributeBaseName(attributeSyntax) == name
    }
  }

  /// Returns the first attribute with the given name from an attribute list, if present.
  static func attribute(
    named name: String,
    in attributes: AttributeListSyntax?,
  ) -> AttributeSyntax? {
    attributes?
      .compactMap { $0.as(AttributeSyntax.self) }
      .first(where: { attributeBaseName($0) == name })
  }

  /// Extracts the last path component of an attribute name, stripping generic arguments and parens.
  static func attributeBaseName(_ attribute: AttributeSyntax) -> String {
    baseName(from: attribute.attributeName)
  }

  /// Extracts the simple base name from a potentially qualified type or attribute.
  static func baseName(from type: TypeSyntax) -> String {
    let description = type.trimmedDescription
    guard !description.isEmpty else {
      return description
    }

    let components = description.split(separator: ".")
    guard let lastComponent = components.last else {
      return description
    }

    let sanitizedComponent = lastComponent
      .split(separator: "(")
      .first?
      .split(separator: "<")
      .first

    return String(sanitizedComponent ?? lastComponent)
  }
}

// By Dennis Müller

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Member macro that synthesizes boilerplate required by `LanguageModelSessionSchema`
/// conformances, including tool wrappers and decoding helpers.
public struct SessionSchemaMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext,
  ) throws -> [DeclSyntax] {
    _ = context
    guard let structDeclaration = declaration.as(StructDeclSyntax.self) else {
      throw MacroError.onlyApplicableToStruct(node: Syntax(node)).asDiagnosticsError()
    }

    let toolProperties = try extractToolProperties(from: structDeclaration)
    let groundingProperties = try extractGroundingProperties(from: structDeclaration)
    let structuredOutputProperties = try extractStructuredOutputProperties(from: structDeclaration)
    let declaredAccessLevel = resolveDeclaredAccessLevel(for: structDeclaration)
    let memberAccessLevel = resolvedMemberAccessLevel(for: declaredAccessLevel)
    let decodedTypesAccessLevel = resolvedDecodedTypesAccessLevel(for: declaredAccessLevel)

    var members: [DeclSyntax] = []

    members.append(
      """
      \(raw: memberAccessLevel.rawValue) nonisolated let decodableTools: [any DecodableTool<DecodedToolRun>]
      """,
    )

    members.append(
      generateStructuredOutputsType(
        for: structuredOutputProperties,
        accessModifier: memberAccessLevel.rawValue,
      ),
    )
    members.append(
      generateStructuredOutputsFunction(
        for: structuredOutputProperties,
        accessModifier: memberAccessLevel.rawValue,
      ),
    )
    members.append(contentsOf: generateInitializers(
      for: toolProperties,
      accessModifier: memberAccessLevel.rawValue,
    ))

    members.append(
      generateDecodedGroundingType(
        for: groundingProperties,
        accessModifier: decodedTypesAccessLevel.rawValue,
      ),
    )
    members.append(
      generateDecodedToolRunEnum(
        for: toolProperties,
        accessModifier: decodedTypesAccessLevel.rawValue,
      ),
    )
    members.append(
      generateDecodedStructuredOutputEnum(
        for: structuredOutputProperties,
        accessModifier: decodedTypesAccessLevel.rawValue,
      ),
    )
    members.append(contentsOf: toolProperties.map { generateDecodableWrapper(for: $0) })
    members.append(contentsOf: generateDecodableStructuredOutputTypes(for: structuredOutputProperties))

    members.append(
      """
      @propertyWrapper
      struct Tool<ToolType: FoundationModels.Tool>
      where ToolType.Arguments: Generable, ToolType.Output: Generable {
        var wrappedValue: ToolType
        init(wrappedValue: ToolType) {
          self.wrappedValue = wrappedValue
        }
      }
      """,
    )

    members.append(
      """
      @propertyWrapper
      struct StructuredOutput<Output: SwiftAgent.StructuredOutput> {
        var wrappedValue: Output.Type
        init(_ wrappedValue: Output.Type) {
          self.wrappedValue = wrappedValue
        }
      }
      """,
    )

    members.append(
      """
      @propertyWrapper
      struct Grounding<Source: Codable & Sendable & Equatable> {
        var wrappedValue: Source.Type
        init(_ wrappedValue: Source.Type) {
          self.wrappedValue = wrappedValue
        }
      }
      """,
    )

    return members
  }

  private enum AccessLevel: String {
    case `public`
    case package
    case `internal`
    case `fileprivate`
    case `private`
  }

  private static func resolveDeclaredAccessLevel(
    for structDeclaration: StructDeclSyntax,
  ) -> AccessLevel {
    for modifier in structDeclaration.modifiers {
      let modifierName = modifier.name.trimmedDescription

      switch modifierName {
      case "public":
        return .public
      case "package":
        return .package
      case "internal":
        return .internal
      case "fileprivate":
        return .fileprivate
      case "private":
        return .private
      default:
        continue
      }
    }

    return .internal
  }

  private static func resolvedMemberAccessLevel(
    for declaredAccessLevel: AccessLevel,
  ) -> AccessLevel {
    switch declaredAccessLevel {
    case .public:
      .public
    case .package:
      .package
    case .internal:
      .internal
    case .fileprivate, .private:
      .fileprivate
    }
  }

  private static func resolvedDecodedTypesAccessLevel(
    for declaredAccessLevel: AccessLevel,
  ) -> AccessLevel {
    switch declaredAccessLevel {
    case .public:
      .public
    case .package:
      .package
    case .internal:
      .internal
    case .fileprivate, .private:
      .internal
    }
  }
}

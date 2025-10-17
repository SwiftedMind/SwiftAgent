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

    var members: [DeclSyntax] = []

    members.append(
      """
      nonisolated let decodableTools: [any DecodableTool<DecodedToolRun>]
      """,
    )

    members.append(generateStructuredOutputsType(for: structuredOutputProperties))
    members.append(generateStructuredOutputsFunction(for: structuredOutputProperties))
    members.append(contentsOf: generateInitializers(for: toolProperties))

    members.append(generateDecodedGroundingType(for: groundingProperties))
    members.append(generateDecodedToolRunEnum(for: toolProperties))
    members.append(generateDecodedStructuredOutputEnum(for: structuredOutputProperties))
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
}

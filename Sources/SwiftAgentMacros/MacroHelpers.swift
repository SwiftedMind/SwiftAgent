// By Dennis Müller

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - Errors

enum MacroError: CustomStringConvertible {
  case mustBeVar(node: Syntax)
  case noBinding(node: Syntax)
  case invalidPattern(node: Syntax)
  case missingTypeAnnotation(node: Syntax)
  case cannotInferType(node: Syntax)
  case onlyApplicableToStruct(node: Syntax)
  case missingGroundingType(node: Syntax)
  case invalidGroundingAttribute(node: Syntax)
  case observedPropertyProvidesInitializer(node: Syntax)
  case missingObservedInitialValue(node: Syntax)

  var description: String {
    String(describing: diagnostic.message)
  }

  var diagnostic: Diagnostic {
    let messageID: MessageID
    let message: String

    switch self {
    case let .mustBeVar(node):
      messageID = MessageID(domain: Self.domain, id: "must-be-var")
      message = "Macro-managed properties must be declared with 'var'"
      return Diagnostic(
        node: node,
        message: MacroDiagnosticMessage(message: message, diagnosticID: messageID, severity: .error),
      )

    case let .noBinding(node):
      messageID = MessageID(domain: Self.domain, id: "no-binding")
      message = "Property has no binding"
      return Diagnostic(
        node: node,
        message: MacroDiagnosticMessage(message: message, diagnosticID: messageID, severity: .error),
      )

    case let .invalidPattern(node):
      messageID = MessageID(domain: Self.domain, id: "invalid-pattern")
      message = "Macro-managed properties must use a simple identifier pattern"
      return Diagnostic(
        node: node,
        message: MacroDiagnosticMessage(message: message, diagnosticID: messageID, severity: .error),
      )

    case let .missingTypeAnnotation(node):
      messageID = MessageID(domain: Self.domain, id: "missing-type-annotation")
      message = "@Tool properties must have explicit type annotations"
      return Diagnostic(
        node: node,
        message: MacroDiagnosticMessage(message: message, diagnosticID: messageID, severity: .error),
      )

    case let .cannotInferType(node):
      messageID = MessageID(domain: Self.domain, id: "cannot-infer-type")
      message = "@Tool cannot infer type from this initializer. Provide an explicit type annotation or use a simple initializer like 'Type()'"
      return Diagnostic(
        node: node,
        message: MacroDiagnosticMessage(message: message, diagnosticID: messageID, severity: .error),
      )

    case let .onlyApplicableToStruct(node):
      messageID = MessageID(domain: Self.domain, id: "only-applicable-to-struct")
      message = "@SessionSchema can only be applied to a struct"
      return Diagnostic(
        node: node,
        message: MacroDiagnosticMessage(message: message, diagnosticID: messageID, severity: .error),
      )

    case let .missingGroundingType(node):
      messageID = MessageID(domain: Self.domain, id: "missing-grounding-type")
      message = "@Grounding requires a type argument like 'Type.self'"
      return Diagnostic(
        node: node,
        message: MacroDiagnosticMessage(message: message, diagnosticID: messageID, severity: .error),
      )

    case let .invalidGroundingAttribute(node):
      messageID = MessageID(domain: Self.domain, id: "invalid-grounding-attribute")
      message = "Invalid @Grounding attribute configuration"
      return Diagnostic(
        node: node,
        message: MacroDiagnosticMessage(message: message, diagnosticID: messageID, severity: .error),
      )

    case let .observedPropertyProvidesInitializer(node):
      messageID = MessageID(domain: Self.domain, id: "observed-property-initializer")
      message = "Remove the initializer; @_LanguageModelProviderObserved manages storage automatically"
      return Diagnostic(
        node: node,
        message: MacroDiagnosticMessage(message: message, diagnosticID: messageID, severity: .error),
      )

    case let .missingObservedInitialValue(node):
      messageID = MessageID(domain: Self.domain, id: "missing-observed-initial-value")
      message = "@_LanguageModelProviderObserved requires an 'initialValue:' argument"
      return Diagnostic(
        node: node,
        message: MacroDiagnosticMessage(message: message, diagnosticID: messageID, severity: .error),
      )
    }
  }

  func diagnose(in context: some MacroExpansionContext) {
    context.diagnose(diagnostic)
  }

  func asDiagnosticsError() -> DiagnosticsError {
    DiagnosticsError(diagnostics: [diagnostic])
  }

  private static let domain = "SessionSchemaMacro"
}

private struct MacroDiagnosticMessage: DiagnosticMessage {
  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity
}

// MARK: - Helpers

extension String {
  func capitalizedFirstLetter() -> String {
    prefix(1).uppercased() + dropFirst()
  }
}

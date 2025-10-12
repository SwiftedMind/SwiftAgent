// By Dennis Müller

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension LanguageModelProviderMacro {
  /// Emits a diagnostic when the user tries to opt out of observation for a property the macro manages.
  static func diagnoseObservationIgnored(
    in classDeclaration: ClassDeclSyntax,
    context: some MacroExpansionContext,
  ) {
    for member in classDeclaration.memberBlock.members {
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
            let ignoredAttribute = attribute(
              named: "ObservationIgnored",
              in: variableDecl.attributes,
            )
      else {
        continue
      }

      MacroError.observationIgnored(node: Syntax(ignoredAttribute)).diagnose(in: context)
    }
  }

  /// Synthesizes stored and computed properties that bridge Observation to macro-managed members.
  static func generateObservableMembers(
    named name: String,
    type: String,
    initialValue: String,
    actorAttribute: String,
    accessModifier: String?,
  ) -> [DeclSyntax] {
    let storedProperty: DeclSyntax =
      """
      \(raw: actorAttribute) private var _\(raw: name): \(raw: type) = \(raw: initialValue)
      """

    let propertyKeyword = accessModifier.map { "\($0) var" } ?? "var"
    let keyPath = "\\.\(name)"
    let computedProperty: DeclSyntax =
      """
      \(raw: actorAttribute) \(raw: propertyKeyword) \(raw: name): \(raw: type) {
        @storageRestrictions(initializes: _\(raw: name))
        init(initialValue) {
          _\(raw: name) = initialValue
        }
        get {
          access(keyPath: \(raw: keyPath))
          return _\(raw: name)
        }
        set {
          guard shouldNotifyObservers(_\(raw: name), newValue) else {
            _\(raw: name) = newValue
            return
          }

          withMutation(keyPath: \(raw: keyPath)) {
            _\(raw: name) = newValue
          }
        }
        _modify {
          access(keyPath: \(raw: keyPath))
          _$observationRegistrar.willSet(self, keyPath: \(raw: keyPath))
          defer {
            _$observationRegistrar.didSet(self, keyPath: \(raw: keyPath))
          }
          yield &_\(raw: name)
        }
      }
      """

    return [storedProperty, computedProperty]
  }

  /// Adds the reusable observation registrar helpers shared by all generated sessions.
  static func generateObservationSupportMembers() -> [DeclSyntax] {
    [
      """
      private let _$observationRegistrar = Observation.ObservationRegistrar()
      """,
      """
      nonisolated func access(
        keyPath: KeyPath<ProviderType, some Any>
      ) {
        _$observationRegistrar.access(self, keyPath: keyPath)
      }
      """,
      """
      nonisolated func withMutation<A>(
        keyPath: KeyPath<ProviderType, some Any>,
        _ mutation: () throws -> A
      ) rethrows -> A {
        try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
      }
      """,
      """
      private nonisolated func shouldNotifyObservers<A>(
        _ lhs: A,
        _ rhs: A
      ) -> Bool {
        true
      }
      """,
      """
      private nonisolated func shouldNotifyObservers<A: Equatable>(
        _ lhs: A,
        _ rhs: A
      ) -> Bool {
        lhs != rhs
      }
      """,
      """
      private nonisolated func shouldNotifyObservers<A: AnyObject>(
        _ lhs: A,
        _ rhs: A
      ) -> Bool {
        lhs !== rhs
      }
      """,
      """
      private nonisolated func shouldNotifyObservers<A: Equatable & AnyObject>(
        _ lhs: A,
        _ rhs: A
      ) -> Bool {
        lhs != rhs
      }
      """,
    ]
  }
}

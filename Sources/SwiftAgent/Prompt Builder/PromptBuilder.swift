// By Dennis Müller

import Foundation

// MARK: - Public Surface

/// A lightweight, composable description of a prompt.
///
/// Use `Prompt` to build human‑readable instructions with sections, tags and plain text.
/// You can either pass a single `PromptRepresentable` value or use the `@PromptBuilder`
/// initializer to compose larger structures.
///
/// Example: Build from a single string
/// ```swift
/// let prompt = Prompt("Hello, world!")
/// print(prompt.formatted()) // "Hello, world!"
/// ```
///
/// Example: Compose with sections and tags
/// ```swift
/// let prompt = Prompt {
///   PromptSection("Instructions") {
///     "Be concise"
///     PromptTag("meta", attributes: ["role": "system"]) {
///       "Internal guidance"
///     }
///   }
/// }
/// ```
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct Prompt: Sendable {
  /// Internal node tree we render later.
  package let nodes: [PromptNode]

  /// Creates a prompt from a single value.
  ///
  /// If you pass a `String`, it becomes a text node. Any custom type may conform to
  /// `PromptRepresentable` to control how it renders.
  public init(_ content: some PromptRepresentable) {
    self = content.promptRepresentation
  }

  /// Creates a prompt using the `@PromptBuilder` result builder.
  ///
  /// Compose text, sections and tags succinctly.
  public init(@PromptBuilder _ content: () throws -> Prompt) rethrows {
    self = try content()
  }

  /// Renders the prompt to a formatted string suitable for LLM input.
  public func formatted() -> String {
    Renderer.render(nodes, indentLevel: 0, headingLevel: 1)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Prompt: PromptRepresentable {
  public var promptRepresentation: Prompt { self }
}

// MARK: - Result Builder

/// Builds `Prompt` values from nested expressions.
///
/// You rarely use `PromptBuilder` directly. Instead, it powers the `Prompt` initializer with
/// `@PromptBuilder` so you can write natural, Markdown‑like structures:
///
/// ```swift
/// let prompt = Prompt {
///   "Title"
///   PromptEmptyLine()
///   PromptSection("Details") {
///     "Body text"
///   }
/// }
/// ```
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
@resultBuilder
public struct PromptBuilder {
  /// Normalize any `PromptRepresentable` to a `Prompt` during expression processing.
  public static func buildExpression(_ expression: some PromptRepresentable) -> Prompt {
    expression.promptRepresentation
  }

  public static func buildExpression(_ expression: Prompt) -> Prompt { expression }

  /// Concatenates multiple child prompts.
  public static func buildBlock(_ components: Prompt...) -> Prompt {
    Prompt(nodes: components.flatMap(\.nodes))
  }

  public static func buildArray(_ prompts: [Prompt]) -> Prompt {
    Prompt(nodes: prompts.flatMap(\.nodes))
  }

  public static func buildEither(first component: Prompt) -> Prompt { component }
  public static func buildEither(second component: Prompt) -> Prompt { component }
  public static func buildOptional(_ component: Prompt?) -> Prompt { component ?? .empty }
  public static func buildLimitedAvailability(_ prompt: Prompt) -> Prompt { prompt }
}

// MARK: - PromptRepresentable

/// A type that can be represented inside a `Prompt`.
///
/// Conform your custom types by returning either a `String` (becomes a text node) or by composing
/// other `Prompt` building blocks such as `PromptSection` or `PromptTag`.
///
/// Minimal conformance:
/// ```swift
/// extension User: PromptRepresentable {
///   @PromptBuilder public var promptRepresentation: Prompt {
///     "User: \(name)"
///   }
/// }
/// ```
///
/// Convenience defaults are provided:
/// - If your type conforms to `CustomStringConvertible`, the description is used automatically
///   once you opt in to `PromptRepresentable`.
/// - If your type is `RawRepresentable` with `RawValue == String`, the raw value is used.
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public protocol PromptRepresentable {
  @PromptBuilder var promptRepresentation: Prompt { get }
}

/// Allow plain Strings in builders.
/// Allows plain strings to be used directly in prompt builders.
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension String: PromptRepresentable {
  public var promptRepresentation: Prompt {
    Prompt(nodes: [.text(self)])
  }
}

/// Convenience: types can opt into PromptRepresentable if they already provide a string description.
///
/// This means a custom type only needs to declare `PromptRepresentable` conformance if it already
/// conforms to `CustomStringConvertible` – the default implementation uses `description`.
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public extension PromptRepresentable where Self: CustomStringConvertible {
  @PromptBuilder var promptRepresentation: Prompt { description }
}

/// Convenience: enums or other wrappers that expose a `String` raw value automatically emit that
/// value when also declaring `PromptRepresentable`.
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public extension PromptRepresentable where Self: RawRepresentable, Self.RawValue == String {
  @PromptBuilder var promptRepresentation: Prompt { rawValue }
}

// MARK: - Structured Types

/// Markdown-style section. Nested sections increment the `#` level.
/// A Markdown‑style section that renders as a `#` heading with nested content.
///
/// Each nested `PromptSection` increases the heading level.
///
/// Example:
/// ```swift
/// PromptSection("Overview") { "Body" }
/// // Renders:
/// // # Overview\nBody
/// ```
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct PromptSection: PromptRepresentable, Sendable {
  public var title: String
  public var content: Prompt

  public init(_ title: String, @PromptBuilder _ content: () throws -> Prompt) rethrows {
    self.title = title
    self.content = try content()
  }

  public var promptRepresentation: Prompt {
    Prompt(nodes: [.section(title: title, children: content.nodes)])
  }
}

/// Represents an empty line in the output.
/// Inserts a single empty line between surrounding content.
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct PromptEmptyLine: PromptRepresentable, Sendable {
  public init() {}

  public var promptRepresentation: Prompt {
    Prompt(nodes: [.emptyLine])
  }
}

/// XML-like tag with optional attributes. Renders `<name a="1">…</name>`.
/// An XML‑like tag with optional attributes.
///
/// Renders either a single self‑closing tag when empty or an open/close tag with indented content.
///
/// Example:
/// ```swift
/// PromptTag("note", attributes: ["type": "system"]) {
///   "Body"
/// }
/// // Renders:
/// // <note type="system">\n  //   Body\n  // </note>
/// ```
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct PromptTag: PromptRepresentable, Sendable {
  public var name: String
  public var attributes: [String: String]
  public var content: Prompt

  public init(
    _ name: String,
    attributes: [String: String] = [:],
    @PromptBuilder _ content: () throws -> Prompt,
  ) rethrows {
    self.name = name
    self.attributes = attributes
    self.content = try content()
  }

  public init(_ name: String, attributes: [String: String] = [:], content: [some PromptRepresentable]) {
    self.name = name
    self.attributes = attributes
    self.content = Prompt {
      for item in content {
        item
      }
    }
  }

  public init(_ name: String, attributes: [String: String] = [:], content: some PromptRepresentable) {
    self.name = name
    self.attributes = attributes
    self.content = Prompt {
      content
    }
  }

  public init(_ name: String, attributes: [String: String] = [:]) {
    self.name = name
    self.attributes = attributes
    content = Prompt(nodes: [])
  }

  public var promptRepresentation: Prompt {
    Prompt(nodes: [.tag(name: name, attributes: attributes, children: content.nodes)])
  }
}

// MARK: - Internals

@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Prompt {
  static let empty = Prompt(nodes: [])

  static func concatenate(_ prompts: [Prompt]) -> Prompt {
    Prompt(nodes: prompts.flatMap(\.nodes))
  }

  package init(nodes: [PromptNode]) {
    self.nodes = nodes
  }
}

@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
package enum PromptNode: Sendable {
  case text(String)
  case section(title: String, children: [PromptNode])
  case tag(name: String, attributes: [String: String], children: [PromptNode])
  case emptyLine
}

@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
package enum Renderer {
  static func render(
    _ nodes: [PromptNode],
    indentLevel: Int,
    headingLevel: Int,
  ) -> String {
    let renderedNodes: [String] = nodes.enumerated().compactMap { index, node in
      let rendered = render(node: node, indentLevel: indentLevel, headingLevel: headingLevel)

      // Skip empty content, but allow emptyLine nodes
      let isEmptyLine = if case .emptyLine = node { true } else { false }
      guard !rendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isEmptyLine else { return nil }

      // Add spacing around sections
      if case .section = node {
        var result = rendered

        // Add empty line before section (unless it's the first node)
        if index > 0 {
          result = "\n" + result
        }

        // Add empty line after nested section (unless it's the last node or top-level)
        if headingLevel > 1, index < nodes.count - 1 {
          result = result + "\n"
        }

        return result
      }

      return rendered
    }

    return renderedNodes.joined(separator: "\n")
  }

  static func render(
    node: PromptNode,
    indentLevel: Int,
    headingLevel: Int,
  ) -> String {
    switch node {
    case let .text(text):
      return indentString(indentLevel) + text

    case let .section(title, children):
      let header = headingPrefix(headingLevel) + " " + title
      let body = render(children, indentLevel: indentLevel, headingLevel: headingLevel + 1)
      if body.isEmpty { return indentString(indentLevel) + header }
      return indentString(indentLevel) + header + "\n" + body

    case let .tag(name, attributes, children):
      let attrs = renderAttributes(attributes)
      if children.isEmpty {
        return indentString(indentLevel) + "<" + name + attrs + " />"
      } else {
        let open = indentString(indentLevel) + "<" + name + attrs + ">"
        let body = render(children, indentLevel: indentLevel + 1, headingLevel: headingLevel)
        let close = indentString(indentLevel) + "</" + name + ">"
        return open + "\n" + body + "\n" + close
      }

    case .emptyLine:
      return ""
    }
  }

  private static func indentString(_ level: Int) -> String {
    String(repeating: "  ", count: max(0, level))
  }

  private static func headingPrefix(_ level: Int) -> String {
    String(repeating: "#", count: min(max(1, level), 6))
  }

  private static func renderAttributes(_ dict: [String: String]) -> String {
    guard !dict.isEmpty else { return "" }

    // Deterministic order for stable output.
    let parts = dict.sorted { $0.key < $1.key }.map { key, value in
      let escaped = value.xmlEscaped()
      return " \(key)=\"\(escaped)\""
    }
    return parts.joined()
  }
}

@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
private extension String {
  func xmlEscaped() -> String {
    var out = self
    out = out.replacingOccurrences(of: "&", with: "&amp;")
    out = out.replacingOccurrences(of: "\"", with: "&quot;")
    out = out.replacingOccurrences(of: "'", with: "&apos;")
    out = out.replacingOccurrences(of: "<", with: "&lt;")
    out = out.replacingOccurrences(of: ">", with: "&gt;")
    return out
  }
}

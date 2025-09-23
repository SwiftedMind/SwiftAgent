---
title: Prompt Builder
---

# Prompt Builder

The Prompt Builder is a tiny DSL for composing clear, structured prompts for AI models. It focuses
on readable Markdown‑style headings and XML‑like tags while keeping plain text ergonomic.

## Core Idea

- `Prompt` is a value type that renders to a single string via `formatted()`.
- Use the `@PromptBuilder` initializer to compose text, sections, and tags.
- Types adopt `PromptRepresentable` to control how they appear inside a prompt.

## Quick Start

```swift
let prompt = Prompt {
  PromptSection("Instructions") {
    "Be concise and accurate"
  }

  PromptSection("Context") {
    PromptTag("meta", attributes: ["role": "system"]) {
      "Internal guidance"
    }
  }
}

let text = prompt.formatted()
```

## Custom Types

Conform your types to `PromptRepresentable` by returning either a `String` or composed content:

```swift
struct User: PromptRepresentable {
  var name: String
  @PromptBuilder var promptRepresentation: Prompt { "User: \(name)" }
}
```

Conveniences:
- If your type is `CustomStringConvertible`, you can opt into `PromptRepresentable` and the
  `description` will be used by default.
- If your type is `RawRepresentable` with `String` raw values, the raw value will be used.

## Built‑In Types

Common Swift types already conform: `String`, `Int`, `Double`, `UUID`, `URL`, and `Date` (ISO‑8601).

## Design Notes

- The underlying node tree is internal. You compose content—no manual node handling required.
- Output is deterministic: attributes are ordered, headings and spacing are normalized.


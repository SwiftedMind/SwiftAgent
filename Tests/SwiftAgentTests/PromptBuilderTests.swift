// By Dennis Müller

@testable import SwiftAgent
import Testing

@Suite("PromptBuilder Tests")
struct PromptBuilderTests {
  @Test("Basic prompt creation from string")
  func basicPromptFromString() {
    let prompt = Prompt("Hello, world!")
    #expect(prompt.formatted() == "Hello, world!")
  }

  @Test("Prompt builder with single string")
  func promptBuilderSingleString() {
    let prompt = Prompt {
      "This is a test prompt"
    }
    #expect(prompt.formatted() == "This is a test prompt")
  }

  @Test("Prompt builder with multiple strings")
  func promptBuilderMultipleStrings() {
    let prompt = Prompt {
      "First line"
      "Second line"
      if true {
        "Conditional line"
      } else {
        "Alternative line"
      }
    }

    #expect(prompt.formatted() == """
    First line
    Second line
    Conditional line
    """)
  }

  @Test("PromptSection basic functionality")
  func promptSectionBasic() {
    let section = PromptSection("Introduction") {
      "Welcome to the guide"
    }

    let formatted = section.promptRepresentation.formatted()
    #expect(formatted == """
    # Introduction
    Welcome to the guide
    """)
  }

  @Test("PromptSection with nested content")
  func promptSectionNested() {
    let section = PromptSection("Main Section") {
      "Main content"
      PromptSection("Subsection") {
        "Nested content"
      }
      "Final content"
    }

    let formatted = section.promptRepresentation.formatted()
    #expect(formatted == """
    # Main Section
    Main content

    ## Subsection
    Nested content

    Final content
    """)
  }

  @Test("PromptTag basic functionality")
  func promptTagBasic() {
    let tag = PromptTag("example") {
      "Tag content"
    }

    let formatted = tag.promptRepresentation.formatted()
    #expect(formatted == """
    <example>
      Tag content
    </example>
    """)
  }

  @Test("PromptTag with attributes")
  func promptTagWithAttributes() {
    let tag = PromptTag("instruction", attributes: ["type": "system"]) {
      "System instruction"
    }

    let formatted = tag.promptRepresentation.formatted()
    #expect(formatted == """
    <instruction type=\"system\">
      System instruction
    </instruction>
    """)
  }

  @Test("Complex prompt structure")
  func complexPromptStructure() {
    let prompt = Prompt {
      PromptSection("Instructions") {
        "Follow these guidelines:"
        PromptEmptyLine()
        PromptTag("rules") {
          "Be concise"
          "Be accurate"
        }
      }

      PromptSection("Context") {
        "User is asking about Swift"
      }
    }

    let result = prompt.formatted()
    #expect(result == """
    # Instructions
    Follow these guidelines:

    <rules>
      Be concise
      Be accurate
    </rules>

    # Context
    User is asking about Swift
    """)
  }

  @Test("Custom type via description default")
  func customTypeDescriptionDefault() {
    struct User: CustomStringConvertible, PromptRepresentable {
      var name: String
      var description: String { "User(\(name))" }
      // No promptRepresentation needed; default uses description
    }

    let user = User(name: "Taylor")
    let prompt = Prompt { user }
    #expect(prompt.formatted() == "User(Taylor)")
  }
}

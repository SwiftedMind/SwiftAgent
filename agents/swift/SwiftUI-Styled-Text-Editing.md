# Styled Text Editing in SwiftUI

## Overview

SwiftUI provides powerful tools for displaying and editing styled text. This guide covers the various ways to style text in SwiftUI, from basic formatting to advanced editing capabilities with AttributedString.

Key components for styled text in SwiftUI:
- `Text`: For displaying read-only styled text
- `AttributedString`: For creating rich text with multiple styles
- `TextEditor`: For editable rich text experiences

## Basic Text Styling

### Font Customization

```swift
// System fonts with different sizes
Text("Hello World")
    .font(.largeTitle)
    .font(.title)
    .font(.headline)
    .font(.subheadline)
    .font(.body)
    .font(.callout)
    .font(.footnote)
    .font(.caption)
    .font(.caption2)

// Custom font size
Text("Custom Size")
    .font(.system(size: 24))

// Font weight
Text("Bold Text")
    .fontWeight(.bold)
    .fontWeight(.semibold)
    .fontWeight(.medium)
    .fontWeight(.regular)
    .fontWeight(.light)
    .fontWeight(.ultraLight)

// Font design
Text("Different Design")
    .font(.system(.body, design: .serif))
    .font(.system(.body, design: .rounded))
    .font(.system(.body, design: .monospaced))
```

### Text Color

```swift
// Basic color
Text("Colored Text")
    .foregroundColor(.blue)

// Using foregroundStyle (preferred in newer SwiftUI versions)
Text("Styled Text")
    .foregroundStyle(.red)

// Using ShapeStyle for gradients
Text("Gradient Text")
    .foregroundStyle(
        .linearGradient(
            colors: [.yellow, .blue],
            startPoint: .top,
            endPoint: .bottom
        )
    )
```

### Text Decoration

```swift
// Bold and italic
Text("Bold Text").bold()
Text("Italic Text").italic()

// Bold and italic with conditional application
Text("Conditionally Bold")
    .bold(someCondition)
    .italic(anotherCondition)

// Underline
Text("Underlined Text")
    .underline()
    .underline(true, color: .red)

// Underline with pattern
Text("Patterned Underline")
    .underline(true, pattern: .dash, color: .blue)

// Strikethrough
Text("Strikethrough Text")
    .strikethrough()
    .strikethrough(true, color: .red)

// Strikethrough with pattern
Text("Patterned Strikethrough")
    .strikethrough(true, pattern: .dot, color: .green)
```

### Text Alignment and Layout

```swift
// Text alignment
Text("Aligned Text")
    .multilineTextAlignment(.center)
    .multilineTextAlignment(.leading)
    .multilineTextAlignment(.trailing)

// Line spacing
Text("Text with\nline spacing")
    .lineSpacing(10)

// Line limit
Text("This text will be truncated if it's too long")
    .lineLimit(1)
    .lineLimit(nil) // No limit

// Truncation mode
Text("Truncated text...")
    .truncationMode(.head)    // ...end of text
    .truncationMode(.middle)  // start...end
    .truncationMode(.tail)    // start... (default)
```

## Advanced Text Styling with AttributedString

### Creating AttributedString

```swift
// Basic AttributedString
var attributedText = AttributedString("This is styled text")

// Styling specific ranges
var complexText = AttributedString("Red and Blue")
if let redRange = complexText.range(of: "Red") {
    complexText[redRange].foregroundColor = .red
}
if let blueRange = complexText.range(of: "Blue") {
    complexText[blueRange].foregroundColor = .blue
}

// Using AttributedString in Text view
Text(attributedText)
```

### Common AttributedString Attributes

```swift
var text = AttributedString("Styled text example")

// Font attributes
text.font = .headline
text.foregroundColor = .blue

// Text presentation
text.backgroundColor = .yellow
text.underlineStyle = .single
text.underlineColor = .red
text.strikethroughStyle = .single
text.strikethroughColor = .green

// Inline presentation intent
text.inlinePresentationIntent = .stronglyEmphasized // Bold
text.inlinePresentationIntent = .emphasized // Italic
```

### Combining Multiple Styles

```swift
var multiStyleText = AttributedString("Multiple styles in one string")

if let firstPart = multiStyleText.range(of: "Multiple styles") {
    multiStyleText[firstPart].font = .headline
    multiStyleText[firstPart].foregroundColor = .blue
}

if let secondPart = multiStyleText.range(of: "one string") {
    multiStyleText[secondPart].font = .body
    multiStyleText[secondPart].foregroundColor = .red
    multiStyleText[secondPart].backgroundColor = .yellow
}

Text(multiStyleText)
```

## Text Editing with TextEditor

### Basic TextEditor

```swift
struct SimpleTextEditorView: View {
    @State private var text = "Edit this text"
    
    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: 100)
            .border(Color.gray)
    }
}
```

### Rich Text Editing with AttributedString

```swift
struct RichTextEditorView: View {
    @State private var text = AttributedString("This is some editable styled text...")
    
    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: 100)
            .border(Color.gray)
    }
}
```

### Text Selection and Formatting

```swift
struct StyledTextEditingView: View {
    @State private var text: AttributedString = AttributedString("Select text to format")
    @State private var selection = AttributedTextSelection()
    
    @Environment(\.fontResolutionContext) private var fontResolutionContext
    
    var body: some View {
        VStack {
            TextEditor(text: $text, selection: $selection)
                .frame(height: 200)
                .border(Color.gray)
            
            HStack {
                // Bold button
                Button(action: {
                    toggleBold()
                }) {
                    Image(systemName: "bold")
                }
                
                // Italic button
                Button(action: {
                    toggleItalic()
                }) {
                    Image(systemName: "italic")
                }
                
                // Underline button
                Button(action: {
                    toggleUnderline()
                }) {
                    Image(systemName: "underline")
                }
                
                // Color picker
                ColorPicker("", selection: Binding(
                    get: { getSelectionColor() },
                    set: { setSelectionColor($0) }
                ))
            }
        }
    }
    
    private func toggleBold() {
        text.transformAttributes(in: &selection) {
            let font = $0.font ?? .default
            let resolved = font.resolve(in: fontResolutionContext)
            $0.font = font.bold(!resolved.isBold)
        }
    }
    
    private func toggleItalic() {
        text.transformAttributes(in: &selection) {
            let font = $0.font ?? .default
            let resolved = font.resolve(in: fontResolutionContext)
            $0.font = font.italic(!resolved.isItalic)
        }
    }
    
    private func toggleUnderline() {
        text.transformAttributes(in: &selection) {
            if $0.underlineStyle != nil {
                $0.underlineStyle = nil
            } else {
                $0.underlineStyle = .single
            }
        }
    }
    
    private func getSelectionColor() -> Color {
        let attributes = selection.typingAttributes(in: text)
        return attributes.foregroundColor ?? .primary
    }
    
    private func setSelectionColor(_ color: Color) {
        text.transformAttributes(in: &selection) {
            $0.foregroundColor = color
        }
    }
}
```

### Custom Text Formatting Definition

```swift
// Define custom formatting constraints
struct MyTextFormatting: AttributedTextFormattingDefinition {
    typealias Scope = AttributeScopes.SwiftUIAttributes
    
    // Allow only specific font weights
    static let fontWeight = ValueConstraint(
        \.font,
        constraint: { font in
            guard let font = font else { return nil }
            let weight = font.resolve().weight
            return font.weight(weight == .bold ? .regular : .bold)
        }
    )
    
    // Allow only specific colors
    static let foregroundColor = ValueConstraint(
        \.foregroundColor,
        constraint: { color in
            guard let color = color else { return nil }
            // Toggle between red and blue
            return color == .red ? .blue : .red
        }
    )
}

// Use the custom formatting
struct CustomFormattedTextEditor: View {
    @State private var text = AttributedString("Custom formatted text")
    @State private var selection = AttributedTextSelection()
    
    var body: some View {
        TextEditor(text: $text, selection: $selection)
            .textFormattingDefinition(MyTextFormatting.self)
    }
}
```

## Markdown Support in Text

SwiftUI's `Text` view supports a subset of Markdown for styling:

```swift
// Basic Markdown styling
Text("This is **bold** and *italic* text")

// Links in Markdown
Text("Visit [Apple](https://www.apple.com)")

// Combining Markdown with modifiers
Text("# Heading\nRegular text")
    .foregroundColor(.blue)
```

### Markdown Limitations

- Text doesn't support all Markdown features
- No support for line breaks, soft breaks, or block-based formatting
- No support for lists, block quotes, code blocks, or tables
- No support for image URLs
- Whitespace is preserved according to `inlineOnlyPreservingWhitespace` parsing option

## Best Practices

### Performance Considerations

- Avoid creating new AttributedString instances frequently
- Cache complex AttributedString objects when possible
- Use appropriate text containers based on content size

### Accessibility

```swift
// Make text more accessible
Text("Accessible Text")
    .font(.body)
    .dynamicTypeSize(.large)
    .accessibilityLabel("Alternative description")
    .accessibilityTextContentType(.plain)
```

### Localization

```swift
// Localizable text
Text("hello.world")  // Looks for "hello.world" in Localizable.strings

// Localized text with styling
Text(LocalizedStringKey("**Bold** and *italic* text"))

// Localized text with variables
Text("Hello, \(username)")
```

## References

- [SwiftUI Text and Symbol Modifiers](https://developer.apple.com/documentation/SwiftUI/View-Text-and-Symbols)
- [Applying Custom Fonts to Text](https://developer.apple.com/documentation/SwiftUI/Applying-Custom-Fonts-to-Text)
- [Building Rich SwiftUI Text Experiences](https://developer.apple.com/documentation/SwiftUI/building-rich-swiftui-text-experiences)
- [Creating Visual Effects with SwiftUI](https://developer.apple.com/documentation/SwiftUI/Creating-visual-effects-with-SwiftUI)
- [Text View Documentation](https://developer.apple.com/documentation/SwiftUI/Text)
- [AttributedString Documentation](https://developer.apple.com/documentation/Foundation/AttributedString)
- [TextEditor Documentation](https://developer.apple.com/documentation/SwiftUI/TextEditor)
# Swift DocC

**Purpose:** Write clear, consistent DocC documentation _in source files_ for Swift APIs.

## Golden Rules

1. **Use triple-slash `///` doc comments** placed immediately above the declaration. Prefer `///` over `/** ... */`.
2. **Start with a single-sentence summary** that ends with a period. Keep it a concise noun/verb phrase (avoid “This method…”). Add additional paragraphs after a blank `///` line when needed.
3. **Document parameters, return value, and thrown errors** using DocC tags in this order:  
   `- Parameter` / `- Parameters:`, `- Returns:`, `- Throws:`. Never leave a tag without a description. Indent wrapped lines by two spaces.
4. **Use singular vs. plural correctly:**  
   _One parameter_ → `- Parameter name:`; _multiple_ → `- Parameters:` then a nested list for each argument. Don’t mix them up.
5. **Include `- Throws:` at most once** per symbol.
6. **Public/Open APIs must be documented**; override docs should only describe behavior that differs from the base. Avoid redundant comments.

## Formatting Inside Doc Comments

- **Paragraphs:** Separate with a blank `///` line.
- **Code voice:** Use backticks for symbol names & inline code (`Collection<Element>`). Use triple backticks for multi-line examples. **Bold** and _italic_ are supported.
- **Callouts / Asides:** Begin a line with `> Note:`, `> Important:`, or `> Warning:` to highlight guidance.

## Tag Cheat-Sheet

- `- Parameter name:` Explain what the argument represents. (Use **singular** when there’s only one.)
- `- Parameters:`  
  `- name:` & `- otherName:` as nested items for multiple parameters.
- `- Returns:` Describe the return value’s meaning, not its type. End with a period.
- `- Throws:` When it can throw, describe the error conditions (exact types if helpful). Only once.

## Minimal Templates

### Function (single parameter, returns, may throw)

```swift
/// Returns a cached value for the provided key.
///
/// - Parameter cacheKey: The unique key used to look up the cached entry.
/// - Returns: The cached value, or `nil` if no entry exists.
/// - Throws: A `CacheError.missingStore` error when the cache backend is unavailable.
func value(for cacheKey: String) throws -> String? { ... }
```

### Function (multiple parameters)

```swift
/// Computes a localized display name from user and locale settings.
///
/// - Parameters:
///   - userProfile: The source of user names and preferences.
///   - localeIdentifier: The BCP-47 locale identifier used for formatting.
/// - Returns: The formatted display name.
func displayName(for userProfile: UserProfile, localeIdentifier: String) -> String { ... }
```

### Type (struct/class)

```swift
/// A thread-safe, in-memory cache for small value types.
///
/// The cache enforces an upper bound on total entries and evicts
/// least-recently-used items when exceeding capacity.
public struct LRUCache<Key: Hashable, Value> { ... }
```

### Property

```swift
/// The maximum number of entries kept in memory.
public var capacity: Int
```

### Initializer

```swift
/// Creates a cache with a specific capacity.
///
/// - Parameter capacity: The maximum number of entries retained before eviction.
public init(capacity: Int) { ... }
```

### Enum Case (with associated values)

```swift
/// A network request completed successfully.
///
/// - Parameter payload: The decoded response body.
case success(payload: DataModel)
```

## Common Pitfalls (auto-fix these)

- **Redundant phrasing:** Replace “This method returns…” with “Returns…”.
- **Wrong tag plurality:** Switch between `Parameter` and `Parameters:` to match arity.
- **Multiple `- Throws:` sections:** Merge into a single `- Throws:` with clear conditions.
- **Missing periods / inconsistent wrapping:** Add trailing periods; wrap continuation lines with two-space indent.

## When to Write Docs (and when not to)

- **Do:** Public/Open declarations and their members; overrides **only** when behavior changes.
- **Don’t:** Add comments that merely restate the obvious or will drift (e.g., “Add `Equatable` conformance.”).

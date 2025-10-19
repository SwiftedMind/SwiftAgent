// By Dennis Müller

// MARK: - Helpers

package func snakeCaseName(for type: (some Any).Type) -> String {
  let name = String(describing: type)
    .replacingOccurrences(of: ".Type", with: "")

  return name.reduce(into: "") { result, char in
    if char.isUppercase, !result.isEmpty {
      result.append("_")
    }
    result.append(char.lowercased())
  }
}

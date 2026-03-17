import SwiftUI

/// Converts a subset of markdown to SwiftUI Text views.
/// Supports: **bold**, *italic*, # headings, - / * bullets, numbered lists.
struct MarkdownText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                lineView(for: line)
            }
        }
    }

    private var lines: [String] {
        text.components(separatedBy: "\n")
    }

    @ViewBuilder
    private func lineView(for line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("### ") {
            styledLine(trimmed.dropFirst(4), size: 15, weight: .semibold)
        } else if trimmed.hasPrefix("## ") {
            styledLine(trimmed.dropFirst(3), size: 17, weight: .bold)
        } else if trimmed.hasPrefix("# ") {
            styledLine(trimmed.dropFirst(2), size: 19, weight: .bold)
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 6) {
                Text("•").foregroundColor(.appAccent).font(.system(size: 14))
                inlineFormatted(String(trimmed.dropFirst(2)))
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if let match = numberedListPrefix(trimmed) {
            HStack(alignment: .top, spacing: 6) {
                Text(match.prefix)
                    .foregroundColor(.appAccent)
                    .font(.system(size: 14, weight: .semibold))
                inlineFormatted(match.rest)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if trimmed.isEmpty {
            Spacer().frame(height: 4)
        } else {
            inlineFormatted(trimmed)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func styledLine(_ substring: Substring, size: CGFloat, weight: Font.Weight) -> some View {
        inlineFormatted(String(substring))
            .font(.system(size: size, weight: weight))
            .padding(.top, 4)
    }

    private func inlineFormatted(_ raw: String) -> Text {
        // Parse **bold**, *italic*, mixed
        var result = Text("")
        var remaining = raw[...]

        while !remaining.isEmpty {
            if remaining.hasPrefix("**"), let end = remaining.dropFirst(2).range(of: "**") {
                let boldContent = remaining.dropFirst(2)[..<end.lowerBound]
                result = result + Text(boldContent).bold().foregroundColor(.appText)
                remaining = remaining.dropFirst(2)[end.upperBound...]
            } else if remaining.hasPrefix("*"), let end = remaining.dropFirst(1).range(of: "*") {
                let italicContent = remaining.dropFirst(1)[..<end.lowerBound]
                result = result + Text(italicContent).italic().foregroundColor(.appText)
                remaining = remaining.dropFirst(1)[end.upperBound...]
            } else {
                let nextSpecial = remaining.range(of: "*")
                let slice = nextSpecial.map { remaining[..<$0.lowerBound] } ?? remaining[...]
                result = result + Text(slice).foregroundColor(.appText)
                remaining = nextSpecial.map { remaining[$0.lowerBound...] } ?? remaining[remaining.endIndex...]
            }
        }
        return result.font(.system(size: 14))
    }

    private struct NumberedMatch { let prefix: String; let rest: String }
    private func numberedListPrefix(_ s: String) -> NumberedMatch? {
        guard let dot = s.firstIndex(of: "."),
              let _ = Int(s[s.startIndex..<dot]) else { return nil }
        let prefix = String(s[s.startIndex...dot])
        let rest = String(s[s.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
        return NumberedMatch(prefix: prefix, rest: rest)
    }
}

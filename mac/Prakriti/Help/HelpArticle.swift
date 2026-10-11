import Foundation

/// The Help window's sections, in the order the sidebar shows them (docs/v2/design-spec.md, 5.2).
/// A section with no visible article is not shown.
enum HelpSection: String, CaseIterable, Sendable {
    case getStarted = "get-started"
    case recording
    case reviewing
    case people
    case direction
    case outputs
    case settings
    case troubleshooting

    /// The name in the sidebar. People and Privacy is called Privacy until faces and voices are built,
    /// because until then Prakriti has no feature called People.
    func title(with capabilities: Set<Capability>) -> String {
        switch self {
        case .getStarted: "Get Started"
        case .recording: "Recording"
        case .reviewing: "Watching and Reviewing"
        case .people: capabilities.contains(.people) ? "People and Privacy" : "Privacy"
        case .direction: "Directing the Edit"
        case .outputs: "Outputs and Uploading"
        case .settings: "Settings and Models"
        case .troubleshooting: "When Something Goes Wrong"
        }
    }
}

/// One Help article: its front matter and its Markdown body, exactly as written in
/// `mac/Prakriti/Resources/Help/NN-name.md`. Blocks for capabilities not built are still in `body`;
/// `HelpLibrary` resolves them before anything is parsed or shown.
struct HelpArticle: Sendable, Equatable, Identifiable {
    /// Stable: links, the Help menu and the remembered last article use it.
    let id: String
    /// "04-sources-and-watching.md": articles link to each other by file name.
    let fileName: String
    let title: String
    let summary: String
    let section: HelpSection
    let order: Int
    let keywords: [String]
    let related: [String]
    /// The whole article is hidden unless this is built.
    let requires: Capability?
    /// Everything after the front matter.
    let body: String

    /// Every field the front matter must carry. `requires` is the only optional one.
    static let requiredFields = ["id", "title", "summary", "section", "order", "keywords", "related"]

    enum ParseError: Error, Equatable, CustomStringConvertible {
        case noFrontMatter
        case missing(String)
        case badValue(field: String, value: String)

        var description: String {
            switch self {
            case .noFrontMatter: "the file does not start with front matter between two --- lines"
            case .missing(let field): "the front matter has no \(field)"
            case .badValue(let field, let value): "the front matter's \(field) cannot be \"\(value)\""
            }
        }
    }

    /// Reads an article file. The front matter is a small YAML subset, the only one the articles use:
    /// `key: value` and `key: [a, b, c]`, one per line.
    static func parse(fileName: String, text: String) throws -> HelpArticle {
        let lines = text.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
              let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            throw ParseError.noFrontMatter
        }
        var fields: [String: String] = [:]
        for line in lines[1..<end] where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let colon = line.firstIndex(of: ":") else { throw ParseError.badValue(field: "line", value: line) }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            fields[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        for field in requiredFields where fields[field] == nil { throw ParseError.missing(field) }

        func list(_ field: String) throws -> [String] {
            let value = fields[field] ?? ""
            guard value.hasPrefix("["), value.hasSuffix("]") else { throw ParseError.badValue(field: field, value: value) }
            return value.dropFirst().dropLast().split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        let sectionValue = fields["section"] ?? ""
        guard let section = HelpSection(rawValue: sectionValue) else { throw ParseError.badValue(field: "section", value: sectionValue) }
        let orderValue = fields["order"] ?? ""
        guard let order = Int(orderValue) else { throw ParseError.badValue(field: "order", value: orderValue) }
        var requires: Capability?
        if let value = fields["requires"] {
            guard let capability = Capability(rawValue: value) else { throw ParseError.badValue(field: "requires", value: value) }
            requires = capability
        }
        let id = fields["id"] ?? ""
        guard !id.isEmpty, id.allSatisfy({ $0.isLowercase || $0.isNumber || $0 == "-" }) else {
            throw ParseError.badValue(field: "id", value: id)
        }
        return HelpArticle(id: id, fileName: fileName, title: fields["title"] ?? "", summary: fields["summary"] ?? "",
                           section: section, order: order, keywords: try list("keywords"), related: try list("related"),
                           requires: requires, body: lines[(end + 1)...].joined(separator: "\n"))
    }
}

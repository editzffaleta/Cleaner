import Foundation

/// Minimal Sparkle appcast XML parser. Extracts the latest version's
/// `sparkle:shortVersionString` (or `sparkle:version`) from an appcast feed.
public final class AppcastParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private var latestVersion: String?
    private var inItem = false

    public override init() { super.init() }

    public func parseLatestVersion(from data: Data) -> String? {
        latestVersion = nil
        inItem = false
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return latestVersion
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String,
                       namespaceURI: String?, qualifiedName: String?,
                       attributes: [String: String] = [:]) {
        if elementName == "item" {
            inItem = true
        }
        if elementName == "enclosure", inItem {
            if let version = attributes["sparkle:shortVersionString"] ?? attributes["sparkle:version"] {
                if latestVersion == nil {
                    latestVersion = version
                }
            }
        }
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String,
                       namespaceURI: String?, qualifiedName: String?) {
        if elementName == "item" {
            inItem = false
        }
    }
}

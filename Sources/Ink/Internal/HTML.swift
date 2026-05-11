/**
*  Ink
*  Copyright (c) John Sundell 2019
*  MIT license, see LICENSE file for details
*/

internal struct HTML: Fragment {
    var modifierTarget: Modifier.Target { .html }

    private var string: Substring

    static func read(using reader: inout Reader) throws -> HTML {
        let startIndex = reader.currentIndex
        let rootElement = try reader.readHTMLElement()

        guard !rootElement.isSelfClosing else {
            let html = reader.characters(in: startIndex..<reader.currentIndex)
            return HTML(string: html)
        }

        var rootElementCount = 1

        while !reader.didReachEnd {
            guard reader.currentCharacter == "<" else {
                reader.advanceIndex()
                continue
            }

            guard var element = try? reader.readHTMLElement() else {
                continue
            }

            guard rootElement.name != element.name else {
                rootElementCount += 1
                continue
            }

            guard element.name.first == "/" else {
                continue
            }

            element.name = element.name.dropFirst()

            if rootElement.name == element.name {
                rootElementCount -= 1
                guard rootElementCount > 0 else { break }
            }
        }

        let html = reader.characters(in: startIndex..<reader.currentIndex)
        return HTML(string: html)
    }

    func html(usingURLs urls: NamedURLCollection,
              modifiers: ModifierCollection) -> String {
        String(string)
    }

    func plainText() -> String {
        // Since we want to strip all HTML from plain text output,
        // there is nothing to return here, just an empty string.
        ""
    }
}

private extension Reader {
    typealias HTMLElement = (name: Substring, isSelfClosing: Bool)

    static var voidElementNames: Set<String> {
        return [
            "area",
            "base",
            "br",
            "col",
            "embed",
            "hr",
            "img",
            "input",
            "link",
            "meta",
            "param",
            "source",
            "track",
            "wbr"
        ]
    }

    mutating func readHTMLElement() throws -> HTMLElement {
        try read("<")
        let startIndex = currentIndex

        while !didReachEnd {
            guard !currentCharacter.isWhitespace, currentCharacter != ">" else {
                let name = characters(in: startIndex..<currentIndex)
                try require(!name.isEmpty)
                let suffix = try readHTMLElementSuffix(forName: name)

                guard name.last != "/" else {
                    return (name.dropLast(), true)
                }

                return (name, suffix.last == "/" || name == "!--" || isVoidHTMLElement(named: name))
            }

            advanceIndex()
        }

        throw Error()
    }

    func isVoidHTMLElement(named name: Substring) -> Bool {
        return Self.voidElementNames.contains(name.lowercased())
    }

    mutating func readHTMLElementSuffix(forName name: Substring) throws -> Substring {
        let startIndex = currentIndex

        guard name != "!--" else {
            var previousCharacter: Character?
            var characterBeforePrevious: Character?

            while !didReachEnd {
                let character = currentCharacter
                let endIndex = currentIndex
                advanceIndex()

                if character == ">",
                   previousCharacter == "-",
                   characterBeforePrevious == "-" {
                    return characters(in: startIndex..<endIndex)
                }

                characterBeforePrevious = previousCharacter
                previousCharacter = character
            }

            throw Error()
        }

        var quote: Character?

        while !didReachEnd {
            let character = currentCharacter

            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                }
            } else {
                if character == "\"" || character == "'" {
                    quote = character
                }

                if character == ">" {
                    let endIndex = currentIndex
                    advanceIndex()
                    return characters(in: startIndex..<endIndex)
                }
            }

            advanceIndex()
        }

        throw Error()
    }
}

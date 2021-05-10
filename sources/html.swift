enum HTML 
{
    struct Tag 
    {
        enum Content 
        {
            case character(Character)
            case child(HTML.Tag)
            
            static 
            func escape(_ content:[Self]) -> [Self] 
            {
                var escaped:[Self] = []
                for content:Self in content 
                {
                    switch content 
                    {
                    case .character("<"):
                        escaped.append(contentsOf: "&lt;".map(Content.character(_:)))
                    case .character(">"):
                        escaped.append(contentsOf: "&gt;".map(Content.character(_:)))
                    case .character("&"):
                        escaped.append(contentsOf: "&amp;".map(Content.character(_:)))
                    case .character("\""):
                        escaped.append(contentsOf: "&quot;".map(Content.character(_:)))
                    default:
                        escaped.append(content)
                    }
                }
                return escaped
            }
        }
        
        let name:String, 
            attributes:[String: String]
        var content:[Content] 
        
        init(_ name:String, _ attributes:[String: String], _ text:String) 
        {
            self.init(name, attributes, content: text.map(Content.character(_:)))
        }
        
        init(_ name:String, _ attributes:[String: String], escaped:String) 
        {
            self.name       = name 
            self.attributes = attributes 
            self.content    = escaped.map(Content.character(_:))
        }
        
        init(_ name:String, _ attributes:[String: String], content:[Content]) 
        {
            self.name       = name 
            self.attributes = attributes 
            self.content    = Content.escape(content)
        }
        
        init(_ name:String, _ attributes:[String: String], _ children:[Self]) 
        {
            self.name       = name 
            self.attributes = attributes 
            self.content    = children.map(Content.child(_:))
        }
        
        var string:String 
        {
            switch self.name 
            {
            // emit self-closing tags ('br')
            case "br":
                return "<\(([self.name] + self.attributes.map{ "\($0.key)=\"\($0.value)\"" }).joined(separator: " "))/>"
            // emit tags with content
            default:
                let content:String = self.content.map 
                {
                    switch $0 
                    {
                    case .character(let c):
                        return "\(c)"
                    case .child(let tag):
                        return tag.string 
                    }
                }.joined()
                return "<\(([self.name] + self.attributes.map{ "\($0.key)=\"\($0.value)\"" }).joined(separator: " "))>\(content)</\(self.name)>"
            }
        }
    }
}

extension Page.Label 
{
    var html:HTML.Tag
    {
        let text:String 
        switch self 
        {
        case .module:
            text = "Module"
        case .plugin:
            text = "Package Plugin"
        case .dependency:
            text = "Dependency"
        case .enumeration:
            text = "Enumeration"
        case .genericEnumeration:
            text = "Generic Enumeration"
        case .importedEnumeration:
            text = "Imported Enumeration"
        case .structure:
            text = "Structure"
        case .genericStructure:
            text = "Generic Structure"
        case .importedStructure:
            text = "Imported Structure"
        case .class:
            text = "Class"
        case .genericClass:
            text = "Generic Class"
        case .importedClass:
            text = "Imported Class"
        case .protocol:
            text = "Protocol"
        case .importedProtocol:
            text = "Imported Protocol"
        case .typealias:
            text = "Typealias"
        case .genericTypealias:
            text = "Generic Typealias"
        case .importedTypealias:
            text = "Imported Typealias"
        case .extension:
            text = "Extension"
        case .enumerationCase:
            text = "Enumeration Case"
        case .initializer:
            text = "Initializer"
        case .staticMethod:
            text = "Static Method"
        case .instanceMethod:
            text = "Instance Method"
        case .genericInitializer:
            text = "Generic Initializer"
        case .genericStaticMethod:
            text = "Generic Static Method"
        case .genericInstanceMethod:
            text = "Generic Instance Method"
        case .staticProperty:
            text = "Static Property"
        case .instanceProperty:
            text = "Instance Property"
        case .associatedtype:
            text = "Associatedtype"
        case .subscript:
            text = "Subscript"
        }
        return .init("div", ["class": "eyebrow"], text)
    }
}
extension Page.Declaration 
{
    static 
    func html(_ tokens:[Token]) -> [HTML.Tag] 
    {
        var i:Int = tokens.startIndex
        var grouped:[HTML.Tag]  = []
        var group:[HTML.Tag]    = []
        while i < tokens.endIndex
        {
            switch tokens[i] 
            {
            case .breakableWhitespace:
                i += 1
                while i < tokens.endIndex, case .breakableWhitespace = tokens[i]
                {
                    i += 1
                }
                
                grouped.append(.init("span", ["class": "syntax-group"], 
                    content: group.map(HTML.Tag.Content.child(_:)) + [.character(" ")]))
                group = []
                continue
            
            case .whitespace:
                group.append(.init("span", ["class": "syntax-whitespace"], escaped: "&nbsp;"))
            case .keyword(let text):
                group.append(.init("span", ["class": "syntax-keyword"], text))
            case .identifier(let text):
                // if any of the characters are operator characters, consider 
                // the identifier to be an operator 
                if text.unicodeScalars.allSatisfy(Grammar.isIdentifierScalar(_:))
                {
                    group.append(.init("span", ["class": "syntax-identifier"], text))
                }
                else 
                {
                    group.append(.init("span", ["class": "syntax-identifier syntax-operator"], text))
                }
            case .type(_, .unresolved), .typePunctuation(_, .unresolved):
                fatalError("attempted to render unresolved link")
            case .type(let text, .resolved(url: let target, style: .local)):
                group.append(.init("a", ["class": "syntax-type", "href": target], text))
            case .type(let text, .resolved(url: let target, style: .imported)):
                group.append(.init("a", ["class": "syntax-type syntax-imported-type", "href": target], text))
            case .type(let text, .resolved(url: let target, style: .apple)):
                group.append(.init("a", ["class": "syntax-type syntax-swift-type", "href": target], text))
            case .typePunctuation(let text, .resolved(url: let target, style: .local)):
                group.append(.init("a", ["class": "syntax-type syntax-punctuation", "href": target], text))
            case .typePunctuation(let text, .resolved(url: let target, style: .imported)):
                group.append(.init("a", ["class": "syntax-type syntax-imported-type syntax-punctuation", "href": target], text))
            case .typePunctuation(let text, .resolved(url: let target, style: .apple)):
                group.append(.init("a", ["class": "syntax-type syntax-swift-type syntax-punctuation", "href": target], text))
            case .punctuation(let text):
                group.append(.init("span", ["class": "syntax-punctuation"], text))
            }
            i += 1
        }
        
        if !group.isEmpty 
        {
            grouped.append(.init("span", ["class": "syntax-group"], 
                content: group.map(HTML.Tag.Content.child(_:))))
        }
        return grouped 
    }
}
extension Page.Signature 
{
    static 
    func html(_ tokens:[Token]) -> [HTML.Tag] 
    {
        var i:Int = tokens.startIndex
        var grouped:[HTML.Tag] = []
        while i < tokens.endIndex
        {
            var group:[HTML.Tag] = []
            darkspace:
            while i < tokens.endIndex
            {
                defer 
                {
                    i += 1
                }
                switch tokens[i] 
                {
                case .text(let text):
                    group.append(.init("span", ["class": "signature-text"], text))
                case .punctuation(let text):
                    group.append(.init("span", ["class": "signature-punctuation"], text))
                case .highlight(let text):
                    // if any of the characters are operator characters, consider 
                    // the identifier to be an operator 
                    if text.unicodeScalars.allSatisfy(Grammar.isIdentifierScalar(_:))
                    {
                        group.append(.init("span", ["class": "signature-highlight"], text))
                    }
                    else 
                    {
                        group.append(.init("span", ["class": "signature-highlight signature-operator"], text))
                    }
                case .whitespace:
                    break darkspace
                }
            }
            
            let content:[HTML.Tag.Content] 
            if grouped.isEmpty 
            {
                content = group.map(HTML.Tag.Content.child(_:))
            }
            else 
            {
                content = [.character(" ")] + group.map(HTML.Tag.Content.child(_:))
            }
            grouped.append(.init("span", ["class": "signature-group"], content: content))
            
            while i < tokens.endIndex, case .whitespace = tokens[i]
            {
                i += 1
            }
        }
        
        return grouped 
    }
}
extension Page 
{
    func breadcrumbs(github:String) -> HTML.Tag 
    {
        let icon:HTML.Tag = .init("li", ["class": "github-icon-container"], 
            [.init("a", ["href": github], 
                [.init("span", ["class": "github-icon", "title": "Github repository"], [])])])
        var breadcrumbs:[HTML.Tag] = self.breadcrumbs.map 
        {
            switch $0.link 
            {
            case .resolved(url: let target, style: _):
                return .init("li", [:], [.init("a", ["href": target], $0.text)])
            case .unresolved(let path):
                fatalError("attempted to render unresolved link \(path)")
            }
        }
        breadcrumbs.append(.init("li", [:], [.init("span", [:], self.breadcrumb)]))
        return .init("div", ["class": "navigation-container"], [.init("ul", [:], [icon] + breadcrumbs)])
    }
    func html(github:String) -> HTML.Tag
    {
        var sections:[HTML.Tag] = [.init("nav", [:], [self.breadcrumbs(github: github)])]
        func create(class:String, section:[HTML.Tag]) 
        {
            sections.append(
                .init("section", ["class": `class`], 
                [.init("div", ["class": "section-container"], section)]))
        }
        
        // intro 
        var introduction:[HTML.Tag] = 
        [
            self.label.html, 
            .init("h1", ["class": "topic-heading"], self.name), 
            self.blurb.isEmpty ? 
                .init("p", ["class": "topic-blurb"], "No overview available") :
                Markdown.html(tag: .p, attributes: ["class": "topic-blurb"], elements: self.blurb),
        ]
        if !self.discussion.required.isEmpty 
        {
            introduction.append(Markdown.html(tag: .p, attributes: ["class": "topic-relationships"], elements: self.discussion.required))
        }
        create(class: "introduction", section: introduction)
        
        // discussion 
        var discussion:[HTML.Tag] 
        if !self.declaration.isEmpty
        {
            discussion = 
            [
                .init("h2", [:], "Declaration"),
                .init("div", ["class": "declaration-container"], 
                    [.init("code", ["class": "declaration"], Page.Declaration.html(self.declaration))])
            ]
        }
        else 
        {
            discussion = []
        }
        
        if !self.discussion.specializations.isEmpty 
        {
            discussion.append(Markdown.html(tag: .p, attributes: ["class": "topic-relationships"], elements: self.discussion.specializations))
        }
        
        if !self.discussion.parameters.isEmpty
        {
            discussion.append(.init("h2", [:], self.label == .enumerationCase ? "Associated values" : "Parameters"))
            var list:[HTML.Tag] = []
            for (name, paragraphs):(String, [[Markdown.Element]]) in self.discussion.parameters 
            {
                list.append(.init("dt", [:], [.init("code", [:], name)]))
                list.append(.init("dd", [:], paragraphs.map 
                {
                    Markdown.html(tag: .p, attributes: [:], elements: $0)
                }))
            }
            discussion.append(.init("dl", ["class": "parameter-list"], list))
        }
        if !self.discussion.return.isEmpty
        {
            discussion.append(.init("h2", [:], "Return value"))
            discussion.append(contentsOf: self.discussion.return.map 
            {
                Markdown.html(tag: .p, attributes: [:], elements: $0)
            })
        }
        if !self.discussion.overview.isEmpty
        {
            discussion.append(.init("h2", [:], "Overview"))
            discussion.append(contentsOf: self.discussion.overview.map 
            {
                Markdown.html(tag: .p, attributes: [:], elements: $0)
            })
        }
        create(class: "discussion", section: discussion)
        // topics 
        if !self.topics.isEmpty 
        {
            var topics:[HTML.Tag] = [.init("h2", [:], "Topics")]
            for (topic, _, symbols):Page.Topic in self.topics 
            {
                let left:HTML.Tag    = .init("h3", [:], topic)
                var right:[HTML.Tag] = []
                
                for (signature, url, blurb, required):Page.TopicSymbol in symbols 
                {
                    var container:[HTML.Tag] = 
                    [
                        .init("code", ["class": "signature"], 
                            [.init("a", ["href": url], Page.Signature.html(signature))])
                    ]
                    if !blurb.isEmpty
                    {
                        container.append(
                            Markdown.html(tag: .p, attributes: ["class": "topic-symbol-blurb"], elements: blurb))
                    }
                    if !required.isEmpty
                    {
                        container.append(
                            Markdown.html(tag: .p, attributes: ["class": "topic-symbol-relationships"], elements: required))
                    }
                    right.append(.init("div", ["class": "topic-container-symbol"], container))
                }
                
                topics.append(.init("div", ["class": "topic"], 
                [
                    .init("div", ["class": "topic-container-right"], [left]),
                    .init("div", ["class": "topic-container-left"], right),
                ]))
            }
            
            create(class: "topics", section: topics)
        }
        
        return .init("main", [:], sections)
    }
}

extension Markdown 
{
    enum Tag 
    {
        case triple 
        case strong 
        case em 
        case code(count:Int) 
        
        case a 
        case p
        case sub 
        case sup 
    }
    static 
    func html(tag:Tag, attributes:[String: String], elements:[Element]) -> HTML.Tag
    {
        var stack:[(tag:Tag, attributes:[String: String], content:[HTML.Tag.Content])] = 
            [(tag, attributes, [])]
        for element:Element in elements 
        {
            switch element 
            {
            case .type: 
                fatalError("unrendered markdown inline swift type")
            case .symbol: 
                fatalError("unrendered markdown symbol link")
            
            case .code(let tokens): 
                stack[stack.endIndex - 1].content.append(.child(
                    .init("code", [:], Page.Declaration.html(tokens))))
            
            /* case .symbol(let link):
                stack[stack.endIndex - 1].content.append(.child(
                    .init("code", [:], (link.paths.map(\.path).flatMap{ $0 } + link.suffix).joined(separator: ".")))) */
            
            case .link(let link):
                var attributes:[String: String] = ["href": link.url, "target": "_blank"]
                if !link.classes.isEmpty 
                {
                    attributes["class"] = link.classes.joined(separator: " ")
                }
                stack[stack.endIndex - 1].content.append(.child(
                    Self.html(tag: .a, attributes: attributes, elements: link.text.map(Element.text(_:)))))
            
            case .sub(let text):
                stack[stack.endIndex - 1].content.append(.child(
                    Self.html(tag: .sub, attributes: [:], elements: text.map(Element.text(_:)))))
            case .sup(let text):
                stack[stack.endIndex - 1].content.append(.child(
                    Self.html(tag: .sup, attributes: [:], elements: text.map(Element.text(_:)))))
            
            case .text(.newline):
                stack[stack.endIndex - 1].content.append(.child(.init("br", [:], content: [])))
            case .text(.wildcard(let c)):
                stack[stack.endIndex - 1].content.append(.character(c))
            
            case .text(.star3):
                switch stack.last
                {
                case (.triple, let attributes, let content)?:
                    stack.removeLast()
                    stack[stack.endIndex - 1].content.append(.child(
                        .init("em", [:], 
                        [
                            .init("strong", attributes, content: content)
                        ])))
                case (.strong, let attributes, let content)?: // treat as '**' '*'
                    stack.removeLast()
                    stack[stack.endIndex - 1].content.append(.child(
                        .init("strong", attributes, content: content)))
                    stack.append((.em, [:], []))
                case (.em, let attributes, let content)?: // treat as '*' '**'
                    stack.removeLast()
                    stack[stack.endIndex - 1].content.append(.child(
                        .init("em", attributes, content: content)))
                    stack.append((.strong, [:], []))
                case (.code, _, _)?: // treat as raw text
                    stack[stack.endIndex - 1].content.append(contentsOf: "***".map(HTML.Tag.Content.character(_:)))
                default:
                    stack.append((.triple, [:], []))
                }
            
            case .text(.star2):
                switch stack.last
                {
                case (.triple, let attributes, let content)?:
                    stack.removeLast()
                    stack.append((.em, attributes, [.child(.init("strong", [:], content: content))]))
                case (.strong, let attributes, let content)?: 
                    stack.removeLast()
                    stack[stack.endIndex - 1].content.append(.child(
                        .init("strong", attributes, content: content)))
                case (.em, let attributes, let content)?: // treat as '*' '*'
                    stack.removeLast()
                    stack[stack.endIndex - 1].content.append(.child(
                        .init("em", attributes, content: content)))
                    stack.append((.em, [:], []))
                case (.code, _, _)?: // treat as raw text
                    stack[stack.endIndex - 1].content.append(contentsOf: "**".map(HTML.Tag.Content.character(_:)))
                default:
                    stack.append((.strong, [:], []))
                }
            
            case .text(.star1):
                switch stack.last
                {
                case (.triple, let attributes, let content)?: // **|*  *
                    stack.removeLast()
                    stack.append((.strong, attributes, [.child(.init("em", [:], content: content))]))
                
                case (.em, let attributes, let content)?: 
                    stack.removeLast()
                    stack[stack.endIndex - 1].content.append(.child(
                        .init("em", attributes, content: content)))
                case (.code, _, _)?: // treat as raw text
                    stack[stack.endIndex - 1].content.append(.character("*"))
                default:
                    stack.append((.em, [:], []))
                }
            
            case .text(.backtick(count: let count)):
                switch stack.last 
                {
                case (.code(count: count), let attributes, let content)?:
                    stack.removeLast()
                    stack[stack.endIndex - 1].content.append(.child(
                        .init("code", attributes, content: content)))
                case (.code(count: _), _, _)?:
                    stack[stack.endIndex - 1].content.append(contentsOf: repeatElement(.character("`"), count: count))
                default:
                    stack.append((.code(count: count), [:], []))
                }
            }
        }
        
        // flatten stack (happens when there are unclosed delimiters)
        while stack.count > 1
        {
            let (tag, _, content):(Tag, [String: String], [HTML.Tag.Content]) = stack.removeLast()
            let plain:[Character] 
            switch tag 
            {
            case .triple:
                plain = ["*", "*", "*"]
            case .strong:
                plain = ["*", "*"]
            case .em:
                plain = ["*"]
            case .code(count: let count):
                plain = .init(repeating: "`", count: count)
            default:
                plain = []
            }
            stack[stack.endIndex - 1].content.append(contentsOf: plain.map(HTML.Tag.Content.character(_:)) + content)
        }
        switch tag 
        {
        case .p:
            return .init("p", attributes, content: stack[stack.endIndex - 1].content)
        case .a:
            return .init("a", attributes, content: stack[stack.endIndex - 1].content)
        case .sub:
            return .init("sub", attributes, content: stack[stack.endIndex - 1].content)
        case .sup:
            return .init("sup", attributes, content: stack[stack.endIndex - 1].content)
        default:
            fatalError("unreachable")
        }
    }
}

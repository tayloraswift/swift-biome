@resultBuilder 
struct HTML 
{
    enum Element
    {
        case text(String)
        case leaf(String, attributes:[String: String]) 
        case node(String, attributes:[String: String], content:HTML) 
    }
    
    private
    var elements:[Element]
    
    mutating 
    func append(@HTML _ build:() -> Self)
    {
        self.elements.append(contentsOf: build().elements)
    }
    
    static 
    func buildExpression(_ unescaped:String) -> Self 
    {
        .init(elements: 
        [
            .text(unescaped.map 
            {
                switch $0 
                {
                case "<"            : return "&lt;"
                case ">"            : return "&gt;"
                case "&"            : return "&amp;"
                case "'"            : return "&apos;"
                case "\""           : return "&quot;"
                case let character  : return "\(character)"
                }
            }.joined())
        ])
    }
    static 
    func buildExpression(_ html:Self) -> Self 
    {
        html
    }
    
    static 
    var empty:Self 
    {
        .init(elements: [])
    }
    static 
    func buildOptional(_ element:Self?) -> Self 
    {
        element ?? .empty
    }
    static 
    func buildEither(first element:Self) -> Self 
    {
        element 
    }
    static 
    func buildEither(second element:Self) -> Self 
    {
        element 
    }
    static 
    func buildArray(_ elements:[Self]) -> Self 
    {
        .init(elements: elements.flatMap(\.elements))
    }
    static 
    func buildBlock(_ elements:Self...) -> Self 
    {
        .init(elements: elements.flatMap(\.elements))
    }
}
extension HTML 
{
    static 
    func element(_ name:String, _ attributes:[String: String] = [:], 
        @HTML builder build:() -> Self = { .empty }) 
        -> Self
    {
        .init(elements: 
        [
            .node(name, attributes: attributes, content: build())
        ])
    }
    static 
    func text(escaped:String) -> Self
    {
        .init(elements: [.text(escaped)])
    }
    static 
    var linebreak:Self 
    {
        .init(elements: [.leaf("br", attributes: [:])])
    }
    
    var rendered:String 
    {
        self.elements.map(\.rendered).joined()
    }
}
extension HTML.Element 
{
    var rendered:String 
    {
        switch self 
        {
        case    .text(let string):
            return string
        case    .leaf(let name, let attributes):
            return
                """
                <\(([name] + attributes.map
                    { 
                        "\($0.key)=\"\($0.value)\"" 
                    }).joined(separator: " "))/>
                """
        case    .node(let name, let attributes, let content):
            return 
                """
                <\(([name] + attributes.map
                    { 
                        "\($0.key)=\"\($0.value)\"" 
                    }).joined(separator: " "))>\
                \(content.rendered)\
                </\(name)>
                """
        }
    }
}

extension Declaration 
{
    @HTML 
    var html:HTML
    {
        let groups:[ArraySlice<Declaration.Token>] = 
            self.tokens.split(separator: .whitespace(breakable: true), 
                omittingEmptySubsequences: false)
        for (index, group):(Int, ArraySlice<Declaration.Token>) in zip(groups.indices, groups)
        {
            if group.isEmpty
            {
                let _ = fatalError("unreachable (multiple consecutive whitespace tokens)")
            }
            
            HTML.element("span", ["class": "syntax-group"])
            {
                for token:Declaration.Token in group 
                {
                    switch token 
                    {
                    case .whitespace(breakable: true):  
                        let _ = fatalError("unreachable")
                    case .whitespace(breakable: false): 
                        HTML.element("span", ["class": "syntax-whitespace"])
                        { 
                            HTML.text(escaped: "&nbsp;") 
                        } 
                    case .keyword(let string): 
                        HTML.element("span", ["class": "syntax-keyword"])
                        {
                            string 
                        }
                    
                    case .identifier(let string, .resolved(url: let url, module: .local)):
                        HTML.element("a", ["href": url, "class": "syntax-type"])
                        {
                            string
                        }
                    case .identifier(let string, .resolved(url: let url, module: .imported)):
                        HTML.element("a", ["href": url, "class": "syntax-type syntax-imported-type"])
                        {
                            string
                        }
                    case .identifier(let string, .resolved(url: let url, module: .swift)):
                        HTML.element("a", ["href": url, "class": "syntax-type syntax-swift-type"])
                        {
                            string
                        }
                    case .identifier(_, .unresolved(path: _)):
                        let _ = fatalError("unreachable (attempted to render unresolved link)")
                    case .identifier(let string, nil):
                        HTML.element("span", ["class": "syntax-identifier"])
                        {
                            string 
                        }
    
                    case .punctuation(let string, .resolved(url: let url, module: .local)):
                        HTML.element("a", ["href": url, "class": "syntax-type syntax-punctuation"])
                        {
                            string
                        }
                    case .punctuation(let string, .resolved(url: let url, module: .imported)):
                        HTML.element("a", ["href": url, "class": "syntax-type syntax-imported-type syntax-punctuation"])
                        {
                            string
                        }
                    case .punctuation(let string, .resolved(url: let url, module: .swift)):
                        HTML.element("a", ["href": url, "class": "syntax-type syntax-swift-type syntax-punctuation"])
                        {
                            string
                        }
                    case .punctuation(_, .unresolved(path: _)):
                        let _ = fatalError("unreachable (attempted to render unresolved link)")
                    case .punctuation(let string, nil):
                        HTML.element("span", ["class": "syntax-punctuation"])
                        {
                            string 
                        }
                    }
                }
                // do not include space for the last group. we cannot use 
                // a “join”, because we want the whitespace character to be 
                // part of the group `span` element.
                if groups.indices.dropLast() ~= index
                {
                    " "
                }
            }
        }
    }
}
extension Signature 
{
    @HTML
    var html:HTML
    {
        let groups:[ArraySlice<Signature.Token>] = 
            self.tokens.split(separator: .whitespace, omittingEmptySubsequences: false)
        for (index, group):(Int, ArraySlice<Signature.Token>) in zip(groups.indices, groups)
        {
            if group.isEmpty
            {
                let _ = fatalError("unreachable (multiple consecutive whitespace tokens)")
            }
            
            HTML.element("span", ["class": "signature-group"])
            {
                // do not include space for the first group. we cannot use 
                // a “join”, because we want the whitespace character to be 
                // part of the group `span` element.
                if groups.indices.dropFirst() ~= index
                {
                    " "
                }
                for token:Signature.Token in group 
                {
                    switch token 
                    {
                    case .whitespace:  
                        let _ = fatalError("unreachable")
                    case .text(let string, highlight: false): 
                        HTML.element("span", ["class": "signature-text"])
                        {
                            string 
                        }
                    case .text(let string, highlight: true):
                        HTML.element("span", ["class": "signature-highlight"])
                        {
                            string 
                        }
                    case .punctuation(let string, highlight: false):
                        HTML.element("span", ["class": "signature-punctuation"])
                        {
                            string 
                        }
                    case .punctuation(let string, highlight: true):
                        HTML.element("span", ["class": "signature-punctuation signature-highlight"])
                        {
                            string 
                        }
                    }
                }
            }
        }
    }
}
extension Page 
{
    func html(github:String) -> HTML 
    {
        HTML.element("main")
        {
            // breadcrumbs
            HTML.element("nav")
            {
                HTML.element("div", ["class": "navigation-container"])
                {
                    HTML.element("ul")
                    {
                        // github icon 
                        HTML.element("li", ["class": "github-icon-container"])
                        {
                            HTML.element("a", ["href": github])
                            {
                                HTML.element("span", ["class": "github-icon", "title": "Github repository"])
                            }
                        }
                        for (text, link):(String, Link) in self.breadcrumbs 
                        {
                            HTML.element("li")
                            {
                                switch link 
                                {
                                case .resolved(url: let target, module: _):
                                    HTML.element("a", ["href": target])
                                    {
                                        text
                                    }
                                case .unresolved(let path):
                                    let _ = print("warning: unresolved link \(path)")
                                    text
                                }
                            }
                        }
                        HTML.element("li")
                        {
                            HTML.element("span")
                            {
                                self.breadcrumb
                            }
                        }
                    }
                }
            }
            // intro 
            HTML.element("section", ["class": "introduction"])
            {
                HTML.element("div", ["class": "section-container"])
                {
                    HTML.element("div", ["class": "eyebrow"])
                    {
                        self.kind.title
                    }
                    HTML.element("h1", ["class": "topic-heading"])
                    {
                        self.name
                    }
                    HTML.element("p", ["class": "topic-blurb"])
                    {
                        if self.blurb.isEmpty 
                        {
                            "No overview available"
                        }
                        else 
                        {
                            Markdown.html(self.blurb)
                        }
                    }
                    if !self.discussion.relationships.isEmpty
                    {
                        for relationship:[Markdown.Element] in self.discussion.relationships
                        {
                            HTML.element("p", ["class": "topic-relationships"])
                            {
                                Markdown.html(relationship)
                            }
                        }
                    }
                }
            }
            // discussion 
            HTML.element("section", ["class": "discussion"])
            {
                HTML.element("div", ["class": "section-container"])
                {
                    if !self.declaration.isEmpty 
                    {
                        HTML.element("h2")
                        {
                            "Declaration"
                        }
                        HTML.element("div", ["class": "declaration-container"])
                        {
                            HTML.element("code", ["class": "declaration"])
                            {
                                self.declaration.html
                            }
                        }
                    }
                    if !self.discussion.specializations.isEmpty 
                    {
                        HTML.element("p", ["class": "topic-relationships"])
                        {
                            Markdown.html(self.discussion.specializations)
                        }
                    }
                    if !self.discussion.parameters.isEmpty
                    {
                        HTML.element("h2")
                        {
                            self.kind == .case ? "Associated values" : "Parameters"
                        }
                        HTML.element("dl", ["class": "parameter-list"])
                        {
                            for (name, paragraphs):(String, [[Markdown.Element]]) in self.discussion.parameters 
                            {
                                HTML.element("dt")
                                {
                                    HTML.element("code")
                                    {
                                        name 
                                    }
                                }
                                HTML.element("dd")
                                {
                                    for paragraph:[Markdown.Element] in paragraphs 
                                    {
                                        HTML.element("p")
                                        {
                                            Markdown.html(paragraph)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if !self.discussion.return.isEmpty
                    {
                        HTML.element("h2")
                        {
                            "Return value"
                        }
                        for paragraph:[Markdown.Element] in self.discussion.return 
                        {
                            HTML.element("p")
                            {
                                Markdown.html(paragraph)
                            }
                        }
                    }
                    if !self.discussion.overview.isEmpty
                    {
                        HTML.element("h2")
                        {
                            "Overview"
                        }
                        for paragraph:[Markdown.Element] in self.discussion.overview 
                        {
                            HTML.element("p")
                            {
                                Markdown.html(paragraph)
                            }
                        }
                    }
                }
            }
            // conforming types 
            if !self.rivers.isEmpty 
            {
                HTML.element("section", ["class": "rivers"])
                {
                    HTML.element("div", ["class": "section-container"])
                    {
                        for river:River in River.allCases 
                        {
                            let elements:[(page:Page, display:Signature, note:[Markdown.Element])] = 
                                self.rivers
                            .filter 
                            {
                                $0.river == river
                            }
                            .map 
                            {
                                ($0.page.target, $0.display, $0.note)
                            }
                            
                            if !elements.isEmpty 
                            {
                                HTML.element("div", ["class": "topic"])
                                {
                                    HTML.element("h2")
                                    {
                                        river.rawValue
                                    }
                                    for (page, signature, note):(Page, Signature, [Markdown.Element]) in elements 
                                    {
                                        HTML.element("div", ["class": "topic-container-symbol"])
                                        {
                                            HTML.element("code", ["class": "signature"])
                                            {
                                                if case .local(url: let url, directory: _) = page.anchor
                                                {
                                                    HTML.element("a", ["href": url])
                                                    {
                                                        signature.html
                                                    }
                                                }
                                                else 
                                                {
                                                    let _ = fatalError("unreachable (missing page url)")
                                                }
                                            }
                                            if !note.isEmpty 
                                            {
                                                HTML.element("p", ["class": "topic-symbol-relationships"])
                                                {
                                                    Markdown.html(note)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // topics 
            if !self.topics.isEmpty 
            {
                HTML.element("section", ["class": "topics"])
                {
                    HTML.element("div", ["class": "section-container"])
                    {
                        HTML.element("h2")
                        {
                            "Topics"
                        }
                        for topic:Page.Topic in self.topics 
                        {
                            HTML.element("div", ["class": "topic"])
                            {
                                HTML.element("div", ["class": "topic-container-left"])
                                {
                                    HTML.element("h3")
                                    {
                                        topic.name
                                    }
                                }
                                HTML.element("div", ["class": "topic-container-right"])
                                {
                                    for element:Page in topic.elements.map(\.target)
                                    {
                                        HTML.element("div", ["class": "topic-container-symbol"])
                                        {
                                            HTML.element("code", ["class": "signature"])
                                            {
                                                if case .local(url: let url, directory: _) = element.anchor
                                                {
                                                    HTML.element("a", ["href": url])
                                                    {
                                                        element.signature.html
                                                    }
                                                }
                                                else 
                                                {
                                                    let _ = fatalError("unreachable (missing page url)")
                                                }
                                            }
                                            if !element.blurb.isEmpty 
                                            {
                                                HTML.element("p", ["class": "topic-symbol-blurb"])
                                                {
                                                    Markdown.html(element.blurb)
                                                }
                                            }
                                            if !element.discussion.relationships.isEmpty 
                                            {
                                                for relationship:[Markdown.Element] in element.discussion.relationships
                                                {
                                                    HTML.element("p", ["class": "topic-symbol-relationships"])
                                                    {
                                                        Markdown.html(relationship)
                                                    }
                                                }
                                            }
                                        }
                                    } 
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

extension Markdown 
{
    static 
    func html(_ elements:[Element]) -> HTML
    {
        enum Context 
        {
            case star3
            case star2
            case star1
            case code(count:Int)
        }
        var stack:[(context:Context?, content:HTML)] = [(nil, .empty)]
        
        // helper functions 
        var context:Context? 
        {
            stack[stack.endIndex - 1].context
        }
        func add(@HTML _ build:() -> HTML) 
        {
            stack[stack.endIndex - 1].content.append(build)
        }
        func push(_ context:Context) 
        {
            stack.append((context, .empty))
        }
        func pop() -> HTML 
        {
            stack.removeLast().content
        }
        
        for element:Element in elements 
        {
            switch element 
            {
            case .type: 
                print("warning: unrendered markdown inline swift type")
                add 
                {
                    "<unrendered>"
                }
            case .symbol: 
                print("warning: unrendered markdown symbol link")
                add 
                {
                    "<unrendered>"
                }
            
            case .code(let code): 
                add 
                {
                    HTML.element("code")
                    {
                        code.html
                    }
                }
            case .link(let link):
                add 
                {
                    HTML.element("a", 
                    [
                        "href":     link.url, 
                        "target":   "_blank", 
                        "class":    link.classes.joined(separator: " ")
                    ])
                    {
                        Self.html(link.text.map(Element.text(_:)))
                    }
                }
            case .sub(let text):
                add 
                {
                    HTML.element("sub")
                    {
                        Self.html(text.map(Element.text(_:)))
                    }
                }
            case .sup(let text):
                add 
                {
                    HTML.element("sup")
                    {
                        Self.html(text.map(Element.text(_:)))
                    }
                }
            case .text(.newline):
                add 
                {
                    HTML.linebreak
                }
            case .text(.wildcard(let c)):
                add 
                {
                    "\(c)"
                }
            case .text(.star3):
                switch context
                {
                case .star3?: 
                    // evaluation order is important 
                    let content:HTML = pop()
                    add
                    {
                        HTML.element("em") 
                        {
                            HTML.element("strong") 
                            {
                                content 
                            }
                        }
                    }
                case .star2?: // treat as '**' '*'
                    let content:HTML = pop()
                    add 
                    {
                        HTML.element("strong") 
                        {
                            content 
                        }
                    }
                    push(.star1)
                case .star1: // treat as '*' '**'
                    let content:HTML = pop()
                    add 
                    {
                        HTML.element("em") 
                        {
                            content 
                        }
                    }
                    push(.star2)
                case .code?: // treat as raw text
                    add 
                    {
                        "***"
                    }
                case nil:
                    push(.star3)
                }
            
            case .text(.star2):
                switch context
                {
                case .star3?:
                    let content:HTML = pop()
                    push(.star1)
                    add 
                    {
                        HTML.element("strong") 
                        {
                            content 
                        }
                    }
                case .star2?: 
                    let content:HTML = pop()
                    add
                    {
                        HTML.element("strong") 
                        {
                            content 
                        }
                    }
                case .star1?: // treat as '**'
                    push(.star2)
                case .code?: // treat as raw text
                    add 
                    {
                        "**"
                    }
                case nil:
                    push(.star2)
                }
            
            case .text(.star1):
                switch context
                {
                case .star3?: // **|*  *
                    let content:HTML = pop()
                    push(.star2)
                    add 
                    {
                        HTML.element("em") 
                        {
                            content 
                        }
                    }
                case .star2?: 
                    push(.star1)
                case .star1?: 
                    let content:HTML = pop()
                    add
                    {
                        HTML.element("em") 
                        {
                            content 
                        }
                    }
                case .code?: // treat as raw text
                    add 
                    {
                        "*"
                    }
                case nil:
                    push(.star1)
                }
            
            case .text(.backtick(count: let count)):
                switch context
                {
                case .code(count: count)?:
                    let content:HTML = pop()
                    add
                    {
                        HTML.element("code") 
                        {
                            content 
                        }
                    }
                case .code(count: _)?: // treat as raw text 
                    add 
                    {
                        String.init(repeating: "`", count: count)
                    }
                default:
                    push(.code(count: count))
                }
            }
        }
        
        // flatten stack (happens when there are unclosed delimiters)
        while true
        {
            let (context, content):(Context?, HTML) = stack.removeLast()
            
            if stack.isEmpty 
            {
                guard context == nil 
                else 
                {
                    fatalError("unreachable")
                }
                return content
            }
            
            let prefix:String 
            switch context 
            {
            case .star3:                    prefix = "***"
            case .star2:                    prefix = "**"
            case .star1:                    prefix = "*"
            case .code(count: let count):   prefix = .init(repeating: "`", count: count)
            case nil:
                add 
                {
                    content
                }
                continue 
            }
            add 
            {
                prefix 
                content  
            }
        }
    }
}

import Markdown
import StructuredDocument 
import HTML

extension Biome 
{
    func article(package _:Int, comment:String) -> Documentation.Article
    {
        .init(comment: comment, biome: self)
    }
    func article(module _:Int, comment:String) -> Documentation.Article
    {
        .init(comment: comment, biome: self)
    }
    func article(symbol index:Int, comment:String) -> Documentation.Article
    {
        if case _? = self.symbols[index].commentOrigin 
        {
            // don’t re-render duplicated docs 
            return .init()
        }
        else 
        {
            return .init(comment: comment, biome: self)
        }
    }
}
extension Documentation 
{
    typealias StaticElement = HTML.Element<Never>
        
    private 
    struct Comment
    {
        let summary:StaticElement?, 
            parameters:[(name:String, comment:[StaticElement])],
            returns:[StaticElement],
            discussion:[StaticElement]
    }
    
    struct Article 
    {
        var errors:[Error]
        private 
        let baked:
        (
            summary:String?, 
            discussion:String?
        )
        
        var summary:Element?
        {
            self.baked.summary.map(Element.text(escaped:))
        }
        var discussion:Element?
        {
            self.baked.discussion.map(Element.text(escaped:))
        }
        
        var size:Int 
        {
            var size:Int = self.baked.summary?.utf8.count     ?? 0
            size        += self.baked.discussion?.utf8.count  ?? 0
            return size
        }
        
        var substitutions:[Anchor: Element] 
        {
            var substitutions:[Anchor: Element] = [:]
            if let summary:Element = self.summary
            {
                substitutions[.summary]     = summary
            }
            if let discussion:Element = self.discussion
            {
                substitutions[.discussion]  = discussion
            }
            return substitutions
        }
                
        init() 
        {
            self.baked = (nil, nil)
            self.errors = []
        }
        
        init(comment:String, biome _:Biome)
        {
            let (comment, errors):(Comment, [Error]) = Self.render(markdown: comment)
            
            var discussion:[StaticElement] = []
            if let section:StaticElement = Self.render(parameters: comment.parameters)
            {
                discussion.append(section)
            }
            if let section:StaticElement = Self.render(section: comment.returns,    heading: "Returns",  class: "returns")
            {
                discussion.append(section)
            }
            if let section:StaticElement = Self.render(section: comment.discussion, heading: "Overview", class: "discussion")
            {
                discussion.append(section)
            }
            
            self.baked.discussion   = discussion.isEmpty ? nil : discussion.map(\.rendered).joined()
            self.baked.summary      = comment.summary?.rendered
            self.errors             = errors 
        }
        
        private static 
        func render(markdown string:String) -> (comment:Comment, errors:[Error])
        {
            if string.isEmpty 
            {
                return (.init(summary: nil, parameters: [], returns: [], discussion: []), [])
            }
            else 
            {
                return Self.render(markdown: Markdown.Document.init(parsing: string))
            }
        }
        // expected parameters is unreliable, not available for subscripts
        private static 
        func render(markdown document:Markdown.Document) -> (comment:Comment, errors:[Error])
        {
            var errors:[Error]          = []
            let content:[StaticElement] = document.blockChildren.map { Self.render(markup: $0, errors: &errors) }
            let head:StaticElement?
            let body:ArraySlice<StaticElement>
            if  let first:StaticElement = content.first, 
                case .container(.p, id: _, attributes: _, content: _) = first
            {
                head = first
                body = content.dropFirst()
            }
            else 
            {
                head = nil 
                body = content[...]
            }
            
            var parameters:[(name:String, comment:[StaticElement])] = []
            var returns:[StaticElement]      = []
            var discussion:[StaticElement]   = []
            for block:StaticElement in body 
            {
                // filter out top-level ‘ul’ blocks, since they may be special 
                guard case .container(.ul, id: let id, attributes: let attributes, content: let items) = block 
                else 
                {
                    discussion.append(block)
                    continue 
                }
                
                var ignored:[StaticElement] = []
                for item:StaticElement in items
                {
                    guard   case .container(.li, id: _, attributes: _, content: let content) = item, 
                            let (keywords, content):([String], [StaticElement]) = Self.keywords(prefixing: content)
                    else 
                    {
                        ignored.append(item)
                        continue 
                    }
                    // `keywords` always contains at least one keyword
                    let keyword:String = keywords[0]
                    do 
                    {
                        switch keyword
                        {
                        case "parameters": 
                            guard keywords.count == 1 
                            else 
                            {
                                throw ArticleAsideError.undefined(keywords: keywords)
                            }
                            parameters.append(contentsOf: try Self.parameters(in: content))
                            
                        case "parameter": 
                            guard keywords.count == 2 
                            else 
                            {
                                throw ArticleAsideError.undefined(keywords: keywords)
                            }
                            let name:String = keywords[1]
                            if content.isEmpty
                            {
                                throw ArticleParametersError.empty(parameter: name)
                            } 
                            parameters.append((name, content))
                        
                        case "returns":
                            guard keywords.count == 1 
                            else 
                            {
                                throw ArticleAsideError.undefined(keywords: keywords)
                            }
                            if content.isEmpty
                            {
                                throw ArticleReturnsError.empty
                            }
                            if returns.isEmpty 
                            {
                                returns = content
                            }
                            else 
                            {
                                throw ArticleReturnsError.duplicate(section: returns)
                            }
                        
                        case "tip", "note", "info", "warning", "throws", "important", "precondition", "complexity":
                            guard keywords.count == 1 
                            else 
                            {
                                throw ArticleAsideError.undefined(keywords: keywords)
                            }
                            discussion.append(StaticElement[.aside]
                            {
                                [keyword]
                            }
                            content:
                            {
                                StaticElement[.h2]
                                {
                                    keyword
                                }
                                
                                content
                            })
                            
                        default:
                            throw ArticleAsideError.undefined(keywords: keywords)
                            /* if case _? = comment.complexity 
                            {
                                print("warning: detected multiple 'complexity' sections, only the last will be used")
                            }
                            guard   let first:Markdown.BlockMarkup = content.first, 
                                    let first:Markdown.Paragraph = first as? Markdown.Paragraph
                            else 
                            {
                                print("warning: could not detect complexity function from section \(content)")
                                ignored.append(item)
                                continue 
                            }
                            let text:String = first.inlineChildren.map(\.plainText).joined()
                            switch text.firstIndex(of: ")").map(text.prefix(through:))
                            {
                            case "O(1)"?: 
                                comment.complexity = .constant
                            case "O(n)"?, "O(m)"?: 
                                comment.complexity = .linear
                            case "O(n log n)"?: 
                                comment.complexity = .logLinear
                            default:
                                print("warning: could not detect complexity function from string '\(text)'")
                                ignored.append(item)
                                continue 
                            } */
                        }
                    }
                    catch let error 
                    {
                        errors.append(error)
                        ignored.append(item)
                    }
                }
                guard ignored.isEmpty 
                else 
                {
                    discussion.append(.container(.ul, id: id, attributes: attributes, content: ignored))
                    continue 
                }
            }
            
            let comment:Comment = .init(summary: head, 
                parameters: parameters, 
                returns: returns, 
                discussion: discussion)
            return (comment, errors)
        }
        private static 
        func render(markup:Markdown.Markup, errors:inout [Error]) -> StaticElement
        {
            let container:HTML.Container 
            switch markup 
            {
            case is Markdown.LineBreak:             return StaticElement[.br]
            case is Markdown.SoftBreak:             return StaticElement.text(escaped: " ")
            case is Markdown.ThematicBreak:         return StaticElement[.hr]
            case let node as Markdown.CustomInline: return StaticElement.text(escaping: node.text)
            case let node as Markdown.Text:         return StaticElement.text(escaping: node.string)
            case let node as Markdown.HTMLBlock:    return StaticElement.text(escaped: node.rawHTML)
            case let node as Markdown.InlineHTML:   return StaticElement.text(escaped: node.rawHTML)
            
            case is Markdown.Document:          container = .main
            case is Markdown.BlockQuote:        container = .blockquote
            case is Markdown.Emphasis:          container = .em
            case let node as Markdown.Heading: 
                switch node.level 
                {
                case 1:                         container = .h2
                case 2:                         container = .h3
                case 3:                         container = .h4
                case 4:                         container = .h5
                default:                        container = .h6
                }
            case is Markdown.ListItem:          container = .li
            case is Markdown.OrderedList:       container = .ol
            case is Markdown.Paragraph:         container = .p
            case is Markdown.Strikethrough:     container = .s
            case is Markdown.Strong:            container = .strong
            case is Markdown.Table:             container = .table
            case is Markdown.Table.Row:         container = .tr
            case is Markdown.Table.Head:        container = .thead
            case is Markdown.Table.Body:        container = .tbody
            case is Markdown.Table.Cell:        container = .td
            case is Markdown.UnorderedList:     container = .ul
            
            case let node as Markdown.CodeBlock: 
                return StaticElement[.pre]
                {
                    ["notebook"]
                }
                content:
                {
                    StaticElement[.code]
                    {
                        StaticElement.highlight("", .newlines)
                        for (text, highlight):(String, SwiftHighlight) in SwiftHighlight.highlight(node.code)
                        {
                            StaticElement.highlight(text, highlight)
                        }
                    }
                }
            case let node as Markdown.InlineCode: 
                return StaticElement[.code]
                {
                    node.code
                }

            case is Markdown.BlockDirective: 
                return StaticElement[.div]
                {
                    "(unsupported block directive)"
                }
            
            case let node as Markdown.Image: 
                // TODO: do something with these
                let _:String?       = node.title 
                let _:[StaticElement]    = node.children.map 
                {
                    Self.render(markup: $0, errors: &errors)
                }
                guard let source:String = node.source
                else 
                {
                    errors.append(ArticleContentError.missingImageSource)
                    return StaticElement[.img]
                }
                return StaticElement[.img]
                {
                    (source, as: HTML.Src.self)
                }
            
            case let node as Markdown.Link: 
                let display:[StaticElement] = node.children.map 
                {
                    Self.render(markup: $0, errors: &errors)
                }
                guard let target:String = node.destination
                else 
                {
                    errors.append(ArticleContentError.missingLinkDestination)
                    return StaticElement[.span]
                    {
                        display
                    }
                }
                return StaticElement[.a]
                {
                    (target, as: HTML.Href.self)
                    HTML.Target._blank
                    HTML.Rel.nofollow
                }
                content:
                {
                    display
                }
                
            case let node as Markdown.SymbolLink: 
                guard let path:String = node.destination
                else 
                {
                    errors.append(ArticleSymbolLinkError.empty)
                    return StaticElement[.code]
                    {
                        "<empty symbol path>"
                    }
                }
                return StaticElement[.code]
                {
                    path
                }
                
            case let node: 
                errors.append(ArticleContentError.unsupported(markup: node))
                return StaticElement[.div]
                {
                    "(unsupported markdown node '\(type(of: node))')"
                }
            }
            return StaticElement[container]
            {
                markup.children.map
                {
                    Self.render(markup: $0, errors: &errors)
                }
            }
        }
        
        static 
        func render(section content:[StaticElement], heading:String, class:String) -> StaticElement?
        {
            guard !content.isEmpty 
            else 
            {
                return nil 
            }
            return StaticElement[.section]
            {
                [`class`]
            }
            content: 
            {
                StaticElement[.h2]
                {
                    heading
                }
                content
            }
        }
        static 
        func render(parameters:[(name:String, comment:[StaticElement])]) -> StaticElement?
        {
            guard !parameters.isEmpty 
            else 
            {
                return nil 
            }
            return StaticElement[.section]
            {
                ["parameters"]
            }
            content: 
            {
                StaticElement[.h2]
                {
                    "Parameters"
                }
                StaticElement[.dl]
                {
                    for (name, comment):(String, [StaticElement]) in parameters 
                    {
                        StaticElement[.dt]
                        {
                            name
                        }
                        StaticElement[.dd]
                        {
                            comment
                        }
                    }
                }
            }
        }
        
        private static
        func parameters(in content:[StaticElement]) throws -> [(name:String, comment:[StaticElement])]
        {
            guard let first:StaticElement = content.first 
            else 
            {
                throw ArticleParametersError.empty(parameter: nil)
            }
            // look for a nested list 
            guard case .container(.ul, id: _, attributes: _, content: let items) = first 
            else 
            {
                throw ArticleParametersError.invalidList(first)
            }
            if case _? = content.dropFirst().first
            {
                throw ArticleParametersError.multipleLists(content)
            }
            
            var parameters:[(name:String, comment:[StaticElement])] = []
            for item:StaticElement in items
            {
                guard   case .container(.li, id: _, attributes: _, content: let content) = item, 
                        let (keywords, content):([String], [StaticElement]) = Self.keywords(prefixing: content), 
                        let name:String = keywords.first, keywords.count == 1
                else 
                {
                    throw ArticleParametersError.invalidListItem(item)
                }
                parameters.append((name, content))
            }
            return parameters
        }
        
        private static
        func keywords(prefixing content:[StaticElement]) -> (keywords:[String], trimmed:[StaticElement])?
        {
            //  p 
            //  {
            //      text 
            //      {
            //          " foo  bar:  "
            //      }
            //      ...
            //  }
            //  ...
            guard   case .container(.p, id: let id, attributes: let attributes, content: var inline)? = content.first, 
                    let first:StaticElement = inline.first 
            else 
            {
                return nil
            }
            let keywords:Substring
            switch first 
            {
            case .text(escaped: let string):
                guard let colon:String.Index = string.firstIndex(of: ":")
                else 
                {
                    return nil
                }
                let remaining:Substring = string[colon...].dropFirst().drop(while: \.isWhitespace)
                if  remaining.isEmpty 
                {
                    inline.removeFirst()
                }
                else 
                {
                    inline[0] = .text(escaped: String.init(remaining))
                }
                keywords = string[..<colon]
            
            // failing example here: https://developer.apple.com/documentation/system/filedescriptor/duplicate(as:retryoninterrupt:)
            // apple docs just drop the parameter
            case .container(let type, id: _, attributes: _, content: let styled):
                switch type 
                {
                case .code, .strong, .em: 
                    break 
                default: 
                    return nil
                }
                guard   case .text(escaped: let prefix)? = styled.first, styled.count == 1,
                        case .text(escaped: let string)? = inline.dropFirst().first, 
                        let colon:String.Index = string.firstIndex(of: ":"), 
                        string[..<colon].allSatisfy(\.isWhitespace)
                else 
                {
                    return nil
                }
                let remaining:Substring = string[colon...].dropFirst().drop(while: \.isWhitespace)
                if  remaining.isEmpty 
                {
                    inline.removeFirst(2)
                }
                else 
                {
                    inline.removeFirst(1)
                    inline[0] = .text(escaped: String.init(remaining))
                }
                keywords = prefix[...]
            default: 
                return nil
            }
            guard let keywords:[String] = Self.keywords(parsing: keywords)
            else 
            {
                return nil
            }
            
            if inline.isEmpty 
            {
                return (keywords, [StaticElement].init(content.dropFirst()))
            }
            else 
            {
                var content:[StaticElement] = content
                    content[0] = .container(.p, id: id, attributes: attributes, content: inline)
                return (keywords, content)
            }
        }
        private static 
        func keywords(parsing string:Substring) -> [String]?
        {
            let keywords:[Substring] = string.split(whereSeparator: \.isWhitespace)
            guard 1 ... 8 ~= keywords.count
            else 
            {
                return nil 
            }
            return keywords.map { $0.lowercased() }
        }
    }
}

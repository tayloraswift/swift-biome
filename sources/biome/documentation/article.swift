import Markdown
import StructuredDocument 
import HTML

extension Biome 
{
    typealias Comment =
    (
        head:HTML.Element<Never>?, 
        parameters:[(name:String, comment:[HTML.Element<Never>])],
        returns:[HTML.Element<Never>],
        discussion:[HTML.Element<Never>]
    )
    
    struct Article 
    {
        typealias Element       = HTML.Element<Anchor>
        typealias StaticElement = HTML.Element<Never>
        
        /* enum Content
        {
            case documented(Element)
            case synthesized(from:Int)
            case inherited(from:Int)
        } */
        var navigator:Element
        {
            .text(escaped: self.baked.navigator)
        }
        var summary:Element?
        {
            self.baked.summary.map(Element.text(escaped:))
        }
        var discussion:Element?
        {
            self.baked.discussion.map(Element.text(escaped:))
        }
        
        let errors:[Error]
        private 
        let baked:
        (
            navigator:String,
            summary:String?, 
            discussion:String?
        )
        
        var size:Int 
        {
            var size:Int = self.baked.navigator.utf8.count
            size        += self.baked.summary?.utf8.count     ?? 0
            size        += self.baked.discussion?.utf8.count  ?? 0
            return size
        }
        
        var substitutions:[Anchor: Element] 
        {
            var substitutions:[Anchor: Element] =
            [
                .navigator:     self.navigator,
            ]
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
        
        init(
            navigator:StaticElement, 
            summary:StaticElement?, 
            discussion:[StaticElement], 
            errors:[Error])
        {
            /* self.card               = .text(escaped: "")
            self.baked.navigator    = ""
            
            self.introduction       = .text(escaped: "")
            
            self.baked.summary      = ""
            self.baked.platforms    = ""
            self.baked.declaration  = ""
            self.baked.discussion   = "" */
            
            self.baked.navigator    = navigator.rendered
            
            self.baked.summary      = summary?.rendered
            self.baked.discussion   = discussion.isEmpty ? nil : discussion.map(\.rendered).joined()
            
            self.errors             = errors 
        }
    }
    
    func article(package index:Int, comment:String) -> Article
    {
        typealias Element       = HTML.Element<Anchor>
        typealias StaticElement = HTML.Element<Never>
        
        let navigator:StaticElement = StaticElement[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            StaticElement[.li] 
            { 
                self.packages[index].name 
            }
        }
        var renderer:ArticleRenderer    = .init(biome: self)
        let comment:Comment             = renderer.content(markdown: comment)
        return .init(
            navigator:      navigator, 
            summary:        comment.head, 
            discussion:
            [
                ArticleRenderer.render(parameters: comment.parameters),
                ArticleRenderer.render(section: comment.returns,       heading: "Returns",  class: "returns"),
                ArticleRenderer.render(section: comment.discussion,    heading: "Overview", class: "discussion"),
            ].compactMap { $0 }, 
            errors:         renderer.errors)
    }
    func article(module index:Int, comment:String) -> Article
    {
        typealias Element       = HTML.Element<Anchor>
        typealias StaticElement = HTML.Element<Never>
        
        let navigator:StaticElement = StaticElement[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            StaticElement[.li] 
            { 
                self.modules[index].title 
            }
        }
        var renderer:ArticleRenderer    = .init(biome: self)
        let comment:Comment             = renderer.content(markdown: comment)
        return .init(
            navigator:      navigator, 
            summary:        comment.head,
            discussion:     
            [
                ArticleRenderer.render(parameters: comment.parameters),
                ArticleRenderer.render(section: comment.returns,       heading: "Returns",  class: "returns"),
                ArticleRenderer.render(section: comment.discussion,    heading: "Overview", class: "discussion"),
            ].compactMap { $0 }, 
            errors:         renderer.errors)
    }
    func article(symbol index:Int, comment:String) -> Article
    {
        typealias Element           = HTML.Element<Anchor>
        typealias StaticElement     = HTML.Element<Never>
        let symbol:Symbol           = self.symbols[index]
        
        var breadcrumbs:[StaticElement]   = [ StaticElement[.li] { symbol.title } ]
        var next:Int?               = symbol.parent
        while let index:Int         = next
        {
            breadcrumbs.append(StaticElement[.li]
            {
                StaticElement.link(self.symbols[index].title, to: self.symbols[index].path.description, internal: true)
            })
            next = self.symbols[index].parent
        }
        breadcrumbs.reverse()
        
        let navigator:StaticElement  = StaticElement[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            breadcrumbs
        }
        
        var renderer:ArticleRenderer    = .init(biome: self)
        let summary:StaticElement?, 
            discussion:[StaticElement]
        if case _? = symbol.commentOrigin 
        {
            // don’t re-render duplicated docs 
            summary             = nil 
            discussion          = []
        }
        else 
        {
            let comment:Comment = renderer.content(markdown: comment)
            summary             = comment.head
            discussion          = 
            [
                ArticleRenderer.render(parameters: comment.parameters),
                ArticleRenderer.render(section: comment.returns,       heading: "Returns",  class: "returns"),
                ArticleRenderer.render(section: comment.discussion,    heading: "Overview", class: "discussion"),
            ].compactMap { $0 }
        }
        return .init(
            navigator:      navigator, 
            summary:        summary, 
            discussion:     discussion, 
            errors:         renderer.errors)
    }
}
extension Biome 
{
    struct ArticleRenderer 
    {
        typealias StaticElement = HTML.Element<Never>
        
        let biome:Biome 
        var errors:[Error]
        
        init(biome:Biome)
        {
            self.biome = biome 
            self.errors = []
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
        
        mutating 
        func content(markdown string:String) -> Comment
        {
            guard !string.isEmpty 
            else 
            {
                return (nil, [], [], [])
            }
            return self.content(markdown: Markdown.Document.init(parsing: string))
        }
        // expected parameters is unreliable, not available for subscripts
        private mutating 
        func content(markdown document:Markdown.Document) -> Comment
        {
            let content:[StaticElement] = document.blockChildren.map { self.render(markup: $0) }
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
                            let (keywords, content):([String], [StaticElement]) = Biome.keywords(prefixing: content)
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
                        self.errors.append(error)
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
            
            return (head, parameters, returns, discussion)
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
                        let (keywords, content):([String], [StaticElement]) = Biome.keywords(prefixing: content), 
                        let name:String = keywords.first, keywords.count == 1
                else 
                {
                    throw ArticleParametersError.invalidListItem(item)
                }
                parameters.append((name, content))
            }
            return parameters
        }
        private mutating  
        func render(markup:Markdown.Markup) -> StaticElement
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
                    self.render(markup: $0)
                }
                guard let source:String = node.source
                else 
                {
                    self.errors.append(ArticleContentError.missingImageSource)
                    return StaticElement[.img]
                }
                return StaticElement[.img]
                {
                    (source, as: HTML.Src.self)
                }
            
            case let node as Markdown.Link: 
                let display:[StaticElement] = node.children.map 
                {
                    self.render(markup: $0)
                }
                guard let target:String = node.destination
                else 
                {
                    self.errors.append(ArticleContentError.missingLinkDestination)
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
                    self.errors.append(ArticleSymbolLinkError.empty)
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
                self.errors.append(ArticleContentError.unsupported(markup: node))
                return StaticElement[.div]
                {
                    "(unsupported markdown node '\(type(of: node))')"
                }
            }
            return StaticElement[container]
            {
                markup.children.map
                {
                    self.render(markup: $0)
                }
            }
        }
    }
}

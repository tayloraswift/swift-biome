import Markdown
import StructuredDocument 
import HTML

extension Documentation
{
    enum CodeBlockLanguage 
    {
        case swift 
        case plain
    }
    
    struct ArticleSurvey 
    {
        let directives:[BlockDirective]
        let heading:ArticleHeading
        let nodes:[ArticleNode]
    }
    enum ArticleHeading 
    {
        case implicit
        case explicit(Heading)
        
        var level:Int 
        {
            switch self 
            {
            case .implicit:                 return 1 
            case .explicit(let heading):    return heading.level
            }
        }
        
        func owner(assuming format:Format) -> UnresolvedLink?
        {
            guard case .explicit(let heading) = self 
            else 
            {
                return nil 
            }
            var spans:LazyMapSequence<MarkupChildren, InlineMarkup>.Iterator = 
                heading.inlineChildren.makeIterator()
            guard   let owner:any InlineMarkup  = spans.next(), 
                    case nil                    = spans.next(), 
                let owner:SymbolLink    = owner as? SymbolLink,
                let owner:String        = owner.destination, !owner.isEmpty
            else 
            {
                return nil
            }
            switch format 
            {
            // FIXME
            case .entrapta, .docc:
                return .docc(normalizing: owner)
            }
        }
    }
    enum ArticleNode 
    {
        case section(Heading, [Self])
        case block(any BlockMarkup)
    }
    
    struct ArticleRenderer 
    {
        typealias Element = Article<UnresolvedLink>.Element 
        
        let format:Format
        let biome:Biome 
        let routing:RoutingTable
        private
        var context:UnresolvedLinkContext
        
        var errors:[Error]
        
        // `level` may skip levels
        private 
        typealias StackFrame = (heading:ArticleHeading, nodes:[ArticleNode])
        
        static 
        func survey(markdown string:String) -> ArticleSurvey
        {
            let root:Markdown.Document = .init(parsing: string, 
                options: [ .parseBlockDirectives, .parseSymbolLinks ])
            return Self.survey(root: root)
        }
        private static 
        func survey(root:Markdown.Document) -> ArticleSurvey
        {
            // partition the top level blocks by heading, and whether they are 
            // a block directive 
            var directives:[BlockDirective] = []
            var blocks:LazyMapSequence<MarkupChildren, BlockMarkup>.Iterator = 
                root.blockChildren.makeIterator()
            
            while let block:any BlockMarkup = blocks.next()
            {
                guard let directive:BlockDirective = block as? BlockDirective
                else 
                {
                    var stack:(base:[StackFrame], top:StackFrame) 
                    stack.top.nodes = []
                    stack.base      = []
                    var next:(any BlockMarkup)?
                    if let heading:Heading = block as? Heading, heading.level <= 1
                    {
                        stack.top.heading = .explicit(heading)
                        next = blocks.next() 
                    }
                    else 
                    {
                        stack.top.heading = .implicit
                        next = block 
                    }
                    
                    while let current:any BlockMarkup = next 
                    {
                        next = blocks.next()
                        
                        guard let heading:Heading = current as? Heading 
                        else 
                        {
                            stack.top.nodes.append(.block(current))
                            continue 
                        }
                        // for example, an `h3` will own everything until the next `h3`.
                        while case .explicit(let authority) = stack.top.heading,
                                heading.level <= authority.level, 
                            // it’s possible for this to return nil, if the article had 
                            // an explicit title, and there is another `h1` somewhere inside 
                            // it. in this case, the root will behave like an ‘h0’ and 
                            // the `h1`s will become children.
                            var top:StackFrame = stack.base.popLast()
                        {
                            top.nodes.append(.section(authority, stack.top.nodes))
                            stack.top = top
                        }
                        // push the new heading onto the stack, which makes it the 
                        // current authority. the level of the new heading is not necessarily 
                        // the level of the previous authority incremented by 1.
                        // it can skip levels, and it can also have the same level, 
                        // if the document contains multiple `h1`s.
                        stack.base.append(stack.top)
                        stack.top.heading   = .explicit(heading)
                        stack.top.nodes     = []
                    }
                    // conclude the survey by pretending the document ends with 
                    // an imaginary `h0` footer.
                    while case .explicit(let authority) = stack.top.heading,
                        var top:StackFrame = stack.base.popLast()
                    {
                        top.nodes.append(.section(authority, stack.top.nodes))
                        stack.top = top
                    }
                    // `case implicit` can only appear in the first element of the stack 
                    // base, so `stack.base` is guaranteed to be empty at this point
                    assert(stack.base.isEmpty)
                    
                    return .init(directives: directives, heading: stack.top.heading, nodes: stack.top.nodes)
                }
                directives.append(directive)
            }
            
            return .init(directives: directives, heading: .implicit, nodes: [])
        }
        
        static 
        func render(_ survey:ArticleSurvey, as format:Format, 
            biome:Biome, 
            routing:RoutingTable, 
            context:UnresolvedLinkContext) 
            -> ArticleContent<UnresolvedLink>
        {
            var renderer:Self = .init(format: format, biome: biome, routing: routing,
                context: context)
            // note: we *never* render the top-level heading. this will either be 
            // auto-generated (for owned symbols), or stored as plain text by the 
            // caller of this function.
            let summary:Element?, 
                remaining:ArraySlice<ArticleNode>
            if case .block(let paragraph as Paragraph)? = survey.nodes.first
            {
                summary = renderer.render(span: paragraph, as: .p)
                remaining = survey.nodes.dropFirst()
            }
            else 
            {
                summary = nil 
                remaining = survey.nodes[...]
            }
            let rank:Int
            switch survey.heading 
            {
            case .implicit: rank = 1
            case .explicit: rank = 0
            }
            var discussion:[Element] = []
            for node:ArticleNode in remaining 
            {
                renderer.render(node: node, demotedBy: rank, into: &discussion)
            }
            
            if case .implicit = survey.heading 
            {
                // this would be better done at the markup level, but swift-markdown 
                // has a terrible block parsing API :/
                discussion = self._sift(discussion, errors: &renderer.errors)
            }
            return .init(errors: renderer.errors, summary: summary, discussion: discussion)
        }
        private mutating 
        func render(node:ArticleNode, demotedBy rank:Int, into elements:inout [Element])
        {
            switch node 
            {
            case .block(let block): 
                // rank should not matter
                elements.append(self.render(block: block, demotedBy: rank))
            case .section(let heading, let children):
                elements.append(self.render(heading: heading, demotedBy: rank))
                for node:ArticleNode in children 
                {
                    self.render(node: node, demotedBy: rank, into: &elements)
                }
            }
        }
        
        private 
        init(format:Format, biome:Biome, routing:RoutingTable, context:UnresolvedLinkContext)
        {
            self.format     = format
            self.biome      = biome 
            self.routing    = routing
            self.context    = context
            self.errors     = []
        }

        private mutating 
        func render<Aside>(aside:Aside, as container:HTML.Container, demotedBy rank:Int) -> Element 
            where Aside:BasicBlockContainer
        {
            Element[container]
            {
                for block:any BlockMarkup in aside.blockChildren 
                {
                    self.render(block: block, demotedBy: rank)
                }
            }
        }
        private mutating 
        func render(block:any BlockMarkup, demotedBy rank:Int) -> Element 
        {
            switch block 
            {
            case let aside as BlockQuote:
                return self.render(aside: aside, as: .blockquote, demotedBy: rank)
            
            case is CustomBlock:
                return Element[.div] { "(unsupported custom block)" }
            case let block as HTMLBlock:
                return Element.text(escaped: block.rawHTML)
            
            case let directive as BlockDirective:
                return self.render(directive: directive, demotedBy: rank)
            case let item as ListItem:
                return self.render(item: item, demotedBy: rank)
            case let list as OrderedList:
                return self.render(list: list, as: .ol, demotedBy: rank)
            case let list as UnorderedList:
                return self.render(list: list, as: .ul, demotedBy: rank)
            case let block as CodeBlock:
                return self.render(code: block.code, 
                    as: block.language.map { $0.lowercased() == "swift" ? .swift : .plain } ?? .swift)
            case let heading as Heading: 
                return self.render(heading: heading, demotedBy: rank)
            case let paragraph as Paragraph:
                return self.render(span: paragraph, as: .p)
            case let table as Table:
                return self.render(table: table)
            case is ThematicBreak: 
                return Element[.hr]
            case let unsupported: 
                self.errors.append(ArticleError.unsupportedMarkdown(unsupported.debugDescription()))
                return Element[.div]
                {
                    "(unsupported block markdown node '\(type(of: unsupported))')"
                }
            }
        }
        private mutating 
        func render(heading:Heading, demotedBy rank:Int) -> Element 
        {
            let level:HTML.Container
            switch heading.level + rank
            {
            case ...1:  level = .h1
            case    2:  level = .h2
            case    3:  level = .h3
            case    4:  level = .h4
            case    5:  level = .h5
            default:    level = .h6
            }
            return self.render(span: heading, as: level)
        }
        private  
        func render(code:String, as language:CodeBlockLanguage) -> Element 
        {
            var fragments:[Element] = [Element.highlight("", .newlines)]
            switch language 
            {
            case .plain: 
                var lines:[Substring] = code.split(separator: "\n", omittingEmptySubsequences: false)
                while case true? = lines.last?.isEmpty 
                {
                    lines.removeLast()
                }
                if let first:Substring = lines.first 
                {
                    fragments.append(.text(escaping: first))
                }
                for next:Substring in lines.dropFirst()
                {
                    fragments.append(.highlight("\n", .newlines))
                    fragments.append(.text(escaping: next))
                }
            case .swift:
                for (text, highlight):(String, SwiftHighlight) in SwiftHighlight.highlight(code)
                {
                    fragments.append(.highlight(text, highlight))
                }
            }
            
            return Element[.pre]
            {
                ["notebook"]
            }
            content:
            {
                Element[.code]
                {
                    fragments
                }
            }
        }
        private mutating 
        func render(directive:BlockDirective, demotedBy rank:Int) -> Element 
        {
            switch directive.name 
            {
            case let undefined:
                return Element[.div]
                {
                    "(unsupported block directive of type '\(undefined)')"
                }
            }
        }
        private mutating 
        func render(item:ListItem, demotedBy rank:Int) -> Element 
        {
            Element[.li]
            {
                for block:any BlockMarkup in item.blockChildren 
                {
                    self.render(block: block, demotedBy: rank)
                }
            }
        }
        private mutating 
        func render<List>(list:List, as container:HTML.Container, demotedBy rank:Int) -> Element 
            where List:ListItemContainer
        {
            Element[container]
            {
                for item:ListItem in list.listItems 
                {
                    self.render(item: item, demotedBy: rank)
                }
            }
        }
        private mutating 
        func render<Row>(row:Row, as container:HTML.Container) -> Element 
            where Row:TableCellContainer
        {
            Element[container]
            {
                for cell:Table.Cell in row.cells
                {
                    self.render(span: cell, as: .td)
                }
            }
        }
        private mutating 
        func render(table:Table) -> Element 
        {
            Element[.table]
            {
                self.render(row: table.head, as: .thead)
                
                Element[.tbody]
                {
                    for row:Table.Row in table.body.rows 
                    {
                        self.render(row: row, as: .tr)
                    }
                }
            }
        }
        
        // inline rendering 
        private mutating 
        func render<Span>(span:Span, as container:HTML.Container) -> Element
            where Span:InlineContainer
        {
            Element[container]
            {
                for span:any InlineMarkup in span.inlineChildren
                {
                    self.render(inline: span)
                }
            }
        }
        private mutating 
        func render(image:Image) -> Element
        {        
            return Element[.figure]
            {
                Element[.img]
                {
                    if let source:String = image.source, !source.isEmpty
                    {
                        (source, as: HTML.Src.self)
                    }
                    else 
                    {
                        let _:Void = self.errors.append(ArticleError.emptyImageSource)
                    }
                    if let title:String = image.title 
                    {
                        (title, as: HTML.Alt.self)
                    }
                }
                self.render(span: image, as: .figcaption)
            }
        }

        private mutating 
        func render(link:Link) -> Element
        {
            guard let string:String = link.destination, !string.isEmpty
            else 
            {
                self.errors.append(ArticleError.emptyLinkDestination)
                return self.render(span: link, as: .span)
            }
            if let colon:String.Index = string.firstIndex(of: ":"), string[..<colon] == "doc"
            {
                let start:String.Index = string.index(after: colon)
                if !string[start...].starts(with: "//")
                {
                    let unresolved:UnresolvedLink = .docc(normalizing: string[start...])
                    // Swift.print("deferred resolving DocC link: \(unresolved)")
                    return .anchor(id: unresolved)
                }
            }
            
            Swift.print("skipped resolving non-docc link '\(string)'")
            return self.present(externalLink: link.inlineChildren.map
            {
                self.render(inline: $0)
            }, to: string)
        }
        private mutating 
        func render(link:SymbolLink) -> Element
        {
            guard let string:String = link.destination
            else 
            {
                self.errors.append(ArticleError.emptyLinkDestination)
                return Element[.code] { "<empty symbol path>" }
            }
            guard let resolved:ResolvedLink = self.resolve(symbol: string)
            else 
            {
                return Element[.code] { string }
            }
            // it’s too difficult to render symbol links eagerly :( 
            // so just kick this into the final-pass substitutions. 
            // if the URIs are very long, this can also save some memory.
            return .anchor(id: .preresolved(resolved))
            // return self.present(reference: resolved)
        }

        private mutating 
        func resolve(symbol string:String) -> ResolvedLink?
        {
            switch self.format 
            {
            // “entrapta”-style symbol links
            case .entrapta: 
                fatalError("UNIMPLEMENTED")
            // “docc”-style symbol links
            case .docc:
                let unresolved:UnresolvedLink = .docc(normalizing: string)
                do 
                {
                    let resolved:ResolvedLink = try self.routing.resolve(
                        base: .biome, // do not allow articles to be resolved
                        link: unresolved, 
                        context: self.context)
                    //Swift.print("resolved symbollink '\(string)' -> \(resolved)")
                    return resolved
                }
                catch let error 
                {
                    self.errors.append(error)
                    Swift.print("failed to resolve symbollink '\(string)'")
                    return nil
                }
            }
        }
        
        private  
        func present(externalLink content:[Element], to destination:String) -> Element
        {
            return Element[.a]
            {
                (destination, as: HTML.Href.self)
                HTML.Target._blank
                HTML.Rel.nofollow
            }
            content:
            {
                content
            } 
        }
        
        private mutating 
        func render(inline:any InlineMarkup) -> Element
        {
            switch inline
            {
            case is LineBreak:
                return Element[.br]
            case is SoftBreak:
                return Element.text(escaped: " ")
            
            case let span as CustomInline: 
                return Element.text(escaping: span.text)
            case let text as Text:
                return Element.text(escaping: text.string)
            case let span as InlineHTML:
                return Element.text(escaped: span.rawHTML)
            case let span as InlineCode: 
                return Element[.code] { span.code }
            case let span as Emphasis:
                return self.render(span: span, as: .em)
            case let span as Strikethrough:
                return self.render(span: span, as: .s)
            case let span as Strong:
                return self.render(span: span, as: .strong)
            case let image as Image: 
                return self.render(image: image)
            case let link as Link: 
                return self.render(link: link)
            case let link as SymbolLink: 
                return self.render(link: link)
                
            case let unsupported: 
                self.errors.append(ArticleError.unsupportedMarkdown(unsupported.debugDescription()))
                return Element[.div]
                {
                    "(unsupported inline markdown node '\(type(of: unsupported))')"
                }
            }
        }
        
        // no good place to put these:
        private 
        enum MagicListItem 
        {
            case parameters([(name:String, comment:[Element])])
            case returns([Element])
            case aside(Element)
        }
        
        private static 
        func _sift(_ toplevel:[Element], errors:inout [Error]) -> [Element]
        {
            var parameters:[(name:String, comment:[Element])] = []
            var returns:[Element]      = []
            var discussion:[Element]   = []
            for block:Element in toplevel 
            {
                // filter out top-level ‘ul’ blocks, since they may be special 
                guard case .container(.ul, attributes: let attributes, content: let items) = block 
                else 
                {
                    discussion.append(block)
                    continue 
                }
                
                var ignored:[Element] = []
                listitems:
                for item:Element in items
                {
                    guard case .container(.li, attributes: _, content: let content) = item 
                    else 
                    {
                        fatalError("unreachable")
                    }
                    do 
                    {
                        switch try Self.magic(item: content)
                        {
                        case nil:
                            ignored.append(item)
                            continue 
                            
                        case .parameters(let group):
                            parameters.append(contentsOf: group)
                        case .returns(let section):
                            if returns.isEmpty 
                            {
                                returns = section
                            }
                            else 
                            {
                                throw Documentation.CommentError.multipleReturnsFields(returns, section)
                            }
                        case .aside(let section):
                            discussion.append(section)
                        }
                        
                        continue listitems
                    }
                    catch let error 
                    {
                        errors.append(error)
                    }
                    
                    ignored.append(item)
                }
                guard ignored.isEmpty 
                else 
                {
                    discussion.append(.container(.ul, attributes: attributes, content: ignored))
                    continue 
                }
            }
            
            var sections:[Element] = []
            if !parameters.isEmpty
            {
                sections.append(Self.section(parameters: parameters))
            }
            if !returns.isEmpty
            {
                sections.append(Self.section(returns, heading: "Returns",  class: "returns"))
            }
            if !discussion.isEmpty
            {
                sections.append(Self.section(discussion, heading: "Overview", class: "discussion"))
            }
            
            return sections
        }
        
        private static 
        func section(_ content:[Element], heading:String, class:String) -> Element
        {
            Element[.section]
            {
                [`class`]
            }
            content: 
            {
                Element[.h2]
                {
                    heading
                }
                content
            }
        }
        private static 
        func section(parameters:[(name:String, comment:[Element])]) -> Element
        {
            Element[.section]
            {
                ["parameters"]
            }
            content: 
            {
                Element[.h2]
                {
                    "Parameters"
                }
                Element[.dl]
                {
                    parameters.flatMap 
                    {
                        (parameter:(name:String, comment:[Element])) in 
                        [
                            Element[.dt]
                            {
                                parameter.name
                            },
                            Element[.dd]
                            {
                                parameter.comment
                            },
                        ]
                    }
                }
            }
        }
        
        private static 
        func magic(item:[Element]) throws -> MagicListItem?
        {
            guard let (keywords, content):([String], [Element]) = Self.keywords(prefixing: item)
            else 
            {
                return nil 
            }
            // `keywords` always contains at least one keyword
            let keyword:String = keywords[0]
            switch keyword
            {
            case "parameters": 
                guard keywords.count == 1 
                else 
                {
                    throw Documentation.CommentError.unsupportedMagicKeywords(keywords)
                }
                return .parameters(try Self.parameters(in: content))
                
            case "parameter": 
                guard keywords.count == 2 
                else 
                {
                    throw Documentation.CommentError.unsupportedMagicKeywords(keywords)
                }
                let name:String = keywords[1]
                if content.isEmpty
                {
                    throw Documentation.CommentError.emptyParameterField(name: name)
                } 
                return .parameters([(name, content)])
            
            case "returns":
                guard keywords.count == 1 
                else 
                {
                    throw Documentation.CommentError.unsupportedMagicKeywords(keywords)
                }
                if content.isEmpty
                {
                    throw Documentation.CommentError.emptyReturnsField
                }
                return .returns(content)
            
            case "tip", "note", "info", "warning", "throws", "important", "precondition", "complexity":
                guard keywords.count == 1 
                else 
                {
                    throw Documentation.CommentError.unsupportedMagicKeywords(keywords)
                }
                return .aside(Element[.aside]
                {
                    [keyword]
                }
                content:
                {
                    Element[.h2]
                    {
                        keyword
                    }
                    
                    content
                })
                
            default:
                throw Documentation.CommentError.unsupportedMagicKeywords(keywords)
            }
        }
        
        private static
        func parameters(in content:[Element]) throws -> [(name:String, comment:[Element])]
        {
            guard let first:Element = content.first 
            else 
            {
                throw Documentation.CommentError.emptyParameterList
            }
            // look for a nested list 
            guard case .container(.ul, attributes: _, content: let items) = first 
            else 
            {
                throw Documentation.CommentError.invalidParameterList(first)
            }
            if let second:Element = content.dropFirst().first
            {
                throw Documentation.CommentError.multipleParameterLists(first, second)
            }
            
            var parameters:[(name:String, comment:[Element])] = []
            for item:Element in items
            {
                guard   case .container(.li, attributes: _, content: let content) = item, 
                        let (keywords, content):([String], [Element]) = Self.keywords(prefixing: content), 
                        let name:String = keywords.first, keywords.count == 1
                else 
                {
                    throw Documentation.CommentError.invalidParameterListItem(item)
                }
                parameters.append((name, content))
            }
            return parameters
        }
        
        private static
        func keywords(prefixing content:[Element]) -> (keywords:[String], trimmed:[Element])?
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
            guard   case .container(.p, attributes: let attributes, content: var inline)? = content.first, 
                    let first:Element = inline.first 
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
            case .container(let type, attributes: _, content: let styled):
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
                return (keywords, [Element].init(content.dropFirst()))
            }
            else 
            {
                var content:[Element] = content
                    content[0] = .container(.p, attributes: attributes, content: inline)
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

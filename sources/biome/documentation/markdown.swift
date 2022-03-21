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
    struct ArticleRenderer 
    {
        typealias Element = Article<UnresolvedLink>.Element 
        
        let format:Format
        let biome:Biome 
        let routing:RoutingTable
        private
        var context:UnresolvedLinkContext
        
        var errors:[Error]
        
        static 
        func render(_ format:Format, article:String, biome:Biome, routing:RoutingTable, namespace:Int) 
            -> (owner:ArticleOwner, body:[Element], errors:[Error])
        {
            var renderer:Self = self.init(format: format, biome: biome, routing: routing,
                context: .init(namespace: namespace, scope: []))
            let (owner, body):(ArticleOwner, [Element]) = 
                renderer.render(article: Self.parse(markdown: article))
            return (owner, body, renderer.errors)
        }
        static 
        func render(_ format:Format, comment:String, biome:Biome, routing:RoutingTable, context:UnresolvedLinkContext) 
            -> (head:Element?, body:[Element], errors:[Error])
        {
            guard !comment.isEmpty 
            else 
            {
                return (nil, [], [])
            }
            var renderer:Self = self.init(format: format, biome: biome, routing: routing, context: context)
            let (head, body):(Element?, [Element]) = 
                renderer.render(comment: Self.parse(markdown: comment), rank: 1)
            return (head, body, renderer.errors)
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
        
        private static 
        func parse(markdown string:String) -> LazyMapSequence<MarkupChildren, BlockMarkup> 
        {
            let document:Markdown.Document = .init(parsing: string, 
                options: [ .parseBlockDirectives, .parseSymbolLinks ])
            return document.blockChildren
        }

        // comments can have any number of h1’s, embedded in them,
        // which will turn into h2s. if the comment starts with an h1, 
        // it will go into the body, and the summary will show 
        // “no overview available”
        private mutating 
        func render<S>(article blocks:S) -> (owner:ArticleOwner, body:[Element])
            where S:Sequence, S.Iterator:Sequence, S.Element == BlockMarkup
        {
            var blocks:S.Iterator = blocks.makeIterator()
            guard   let first:any BlockMarkup = blocks.next()
            else 
            {
                fatalError("article is completely empty")
            }
            guard   let heading:Heading = first as? Heading, 
                        heading.level == 1
            else 
            {
                let title:String    = "(untitled)"
                var body:[Element]  = [self.render(block: first, rank: 0)]
                while let next:any BlockMarkup = blocks.next()
                {
                    body.append(self.render(block: next, rank: 0))
                }
                return (.free(title: title), body)
            }
            // for some reason, `Heading.inlineChildren.first` appears to be broken
            // this is probably because `any` lookup doesn’t work with `Self.first`
            // and `Self.first(where:)` overloading...
            let _inline:[InlineMarkup]  = .init(heading.inlineChildren)
            guard   _inline.count <= 1,
                let inline:InlineMarkup = _inline.first,
                let owner:SymbolLink    = inline as? SymbolLink,
                let owner:String        = owner.destination, !owner.isEmpty,
                let owner:ResolvedLink  = self.resolve(symbol: owner)
            else 
            {
                let title:String    = heading.plainText
                let body:[Element]  = blocks.map 
                {
                    self.render(block: $0, rank: 0)
                }
                return (.free(title: title), body)
            }
            // the article has an owner. update the scope accordingly 
            // (namespace is never allowed to change)
            if case .symbol(let witness, let victim) = owner 
            {
                self.context.scope = self.biome.context(witness: witness, victim: victim)
            }
            // consider the remainder of the document a comment, but do not 
            // demote the header rank
            let (head, body):(Element?, [Element]) = self.render(comment: blocks, rank: 0)
            switch owner 
            {
            case .article:
                // a symbol link (self.resolve(symbol:)) can never refer to 
                // an article!
                fatalError("unreachable")
            
            case .module(let index):
                return (.module(summary: head, index: index), body)
            case .symbol(let witness, victim: nil):
                return (.symbol(summary: head, index: witness), body)
            case .symbol(_, victim: _?):
                fatalError("UNIMPLEMENTED")
            }
        }
        private mutating 
        func render<S>(comment blocks:S, rank:Int) -> (head:Element?, body:[Element])
            where S:Sequence, S.Element == BlockMarkup
        {
            var blocks:S.Iterator = blocks.makeIterator()
            guard let first:BlockMarkup = blocks.next()
            else 
            {
                return (nil, [])
            }
            let head:Element? 
            var body:[Element]
            if let paragraph:Paragraph = first as? Paragraph 
            {
                head = self.render(span: paragraph, as: .p)
                body = []
            }
            else 
            {
                head = nil 
                body = [self.render(block: first, rank: rank)]
            }
            while let next:BlockMarkup = blocks.next()
            {
                body.append(self.render(block: next, rank: rank))
            }
            return (head, body)
        }
        
        private mutating 
        func render<Aside>(aside:Aside, as container:HTML.Container, rank:Int) -> Element 
            where Aside:BasicBlockContainer
        {
            Element[container]
            {
                for block:any BlockMarkup in aside.blockChildren 
                {
                    self.render(block: block, rank: rank)
                }
            }
        }
        private mutating 
        func render(block:any BlockMarkup, rank:Int) -> Element 
        {
            switch block 
            {
            case let aside as BlockQuote:
                return self.render(aside: aside, as: .blockquote, rank: rank)
            
            case is CustomBlock:
                return Element[.div] { "(unsupported custom block)" }
            case let block as HTMLBlock:
                return Element.text(escaped: block.rawHTML)
            
            case let directive as BlockDirective:
                return self.render(directive: directive, rank: rank)
            case let item as ListItem:
                return self.render(item: item, rank: rank)
            case let list as OrderedList:
                return self.render(list: list, as: .ol, rank: rank)
            case let list as UnorderedList:
                return self.render(list: list, as: .ul, rank: rank)
            case let block as CodeBlock:
                return self.render(code: block.code, 
                    as: block.language.map { $0.lowercased() == "swift" ? .swift : .plain } ?? .swift)
            case let heading as Heading: 
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
        func render(directive:BlockDirective, rank:Int) -> Element 
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
        func render(item:ListItem, rank:Int) -> Element 
        {
            Element[.li]
            {
                for block:any BlockMarkup in item.blockChildren 
                {
                    self.render(block: block, rank: rank)
                }
            }
        }
        private mutating 
        func render<List>(list:List, as container:HTML.Container, rank:Int) -> Element 
            where List:ListItemContainer
        {
            Element[container]
            {
                for item:ListItem in list.listItems 
                {
                    self.render(item: item, rank: rank)
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
    }
}

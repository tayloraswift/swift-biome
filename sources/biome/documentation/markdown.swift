import Markdown
import StructuredDocument 
import HTML

extension Documentation
{
    typealias ArticleRenderingContext = 
    (
        namespace:Int,
        path:Void
    )
    struct ArticleRenderer 
    {
        typealias Element = HTML.Element<Never>
        
        let biome:Biome 
        let routing:RoutingTable
        let context:ArticleRenderingContext
        
        var errors:[Error]
        
        static 
        func render(article:String, biome:Biome, routing:RoutingTable, context:ArticleRenderingContext) 
            -> (owner:ArticleOwner, body:[Element], errors:[Error])
        {
            var renderer:Self = self.init(biome: biome, routing: routing, context: context)
            let (owner, body):(ArticleOwner, [Element]) = renderer.render(article: 
                Markdown.Document.init(parsing: article).blockChildren)
            return (owner, body, renderer.errors)
        }
        static 
        func render(comment:String, biome:Biome, routing:RoutingTable, context:ArticleRenderingContext) 
            -> (head:Element?, body:[Element], errors:[Error])
        {
            guard !comment.isEmpty 
            else 
            {
                return (nil, [], [])
            }
            var renderer:Self = self.init(biome: biome, routing: routing, context: context)
            let (head, body):(Element?, [Element]) = renderer.render(comment: 
                Markdown.Document.init(parsing: comment).blockChildren, rank: 1)
            return (head, body, renderer.errors)
        }

        private 
        init(biome:Biome, routing:RoutingTable, context:ArticleRenderingContext)
        {
            self.biome      = biome 
            self.routing    = routing
            self.context    = context
            self.errors     = []
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
            let _inline:[InlineMarkup]          = .init(heading.inlineChildren)
            guard   _inline.count <= 1,
                let inline:InlineMarkup         = _inline.first,
                let owner:SymbolLink            = inline as? SymbolLink,
                let owner:Documentation.Index   = try? self.resolve(link: owner)
            else 
            {
                let title:String    = heading.plainText
                let body:[Element]  = blocks.map 
                {
                    self.render(block: $0, rank: 0)
                }
                return (.free(title: title), body)
            }
            // consider the remainder of the document a comment, but do not 
            // demote the header rank
            let (head, body):(Element?, [Element]) = 
                self.render(comment: blocks, rank: 0)
            switch owner 
            {
            case .module(let index):
                return (.module(summary: head, index: index), body)
            case .symbol(let witness, victim: nil):
                return (.symbol(summary: head, index: witness), body)
            default: 
                fatalError("unsupported")
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
        
        // general 
        /* private mutating 
        func render(document:Markdown.Document, rank:Int = 0) -> Element 
        {
            Element[.main]
            {
                for block:any BlockMarkup in document.blockChildren 
                {
                    self.render(block: block, rank: rank)
                }
            }
        } */
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
                return self.render(code: block.code)
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
        func render(code:String) -> Element 
        {
            Element[.pre]
            {
                ["notebook"]
            }
            content:
            {
                Element[.code]
                {
                    Element.highlight("", .newlines)
                    for (text, highlight):(String, SwiftHighlight) in SwiftHighlight.highlight(code)
                    {
                        Element.highlight(text, highlight)
                    }
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
            guard let target:String = link.destination, !target.isEmpty
            else 
            {
                self.errors.append(ArticleError.emptyLinkDestination)
                return self.render(span: link, as: .span)
            }
            return Element[.a]
            {
                (target, as: HTML.Href.self)
                HTML.Target._blank
                HTML.Rel.nofollow
            }
            content:
            {
                for span:any InlineMarkup in link.inlineChildren
                {
                    self.render(inline: span)
                }
            }
        }
        private mutating 
        func render(link:SymbolLink) -> Element
        {
            let components:[(text:String, uri:URI)], 
                tail:(text:String, uri:URI)
            do 
            {
                switch try self.resolve(link: link) 
                {
                case .ambiguous, .packageSearchIndex: 
                    fatalError("unreachable")
                case .package(let package):
                    components  = []
                    tail        = 
                    (
                        self.biome.packages[package].id.name,
                        self.biome.uri(package: package)
                    )
                case .module(let module):
                    components  = []
                    tail        = 
                    (
                        self.biome.modules[module].title,
                        self.biome.uri(module: module)
                    )
                case .symbol(let witness, victim: let victim):
                    var reversed:[(text:String, uri:URI)] = []
                    var next:Int?       = victim ?? self.biome.symbols[witness].parent
                    while let index:Int = next
                    {
                        reversed.append(
                            (
                                self.biome.symbols[index].title, 
                                self.biome.uri(witness: index, victim: nil, routing: self.routing)
                            ))
                        next    = self.biome.symbols[index].parent
                    }
                    components  = reversed.reversed()
                    tail        = 
                    (
                        self.biome.symbols[witness].title, 
                        self.biome.uri(witness: witness, victim: victim, routing: self.routing)
                    )
                }
            }
            catch let error 
            {
                self.errors.append(error)
                return Element[.code] { link.destination ?? "<empty symbol path>" }
            }
            return Element[.code]
            {
                // unlike in breadcrumbs, we print the dot separators explicitly 
                // so they look normal when highlighted and copy-pasted 
                for (text, uri):(String, URI) in components 
                {
                    Element.link(text, to: self.biome.print(prefix: self.routing.prefix, uri: uri), internal: true)
                    Element.text(escaped: ".")
                }
                Element.link(tail.text, to: self.biome.print(prefix: self.routing.prefix, uri: tail.uri), internal: true)
            }
        }
        private 
        func resolve(link:SymbolLink) throws -> Documentation.Index 
        {
            guard   let destination:String  = link.destination, 
                    let first:Character     = destination.first
            else 
            {
                throw ArticleError.undefinedSymbolLink(.init(stem: [], leaf: []), overload: nil)
            }
            
            Swift.print("resolving symbol link ``\(destination)``")
            
            //  ``relativename`` -> ['package-name/relativename', 'package-name/modulename/relativename']
            //  ``/absolutename`` -> ['absolutename']
            let path:URI.Path
            let resolved:Documentation.Index
            var ignored:Bool    = false 
            if first == "/"
            {
                path = .normalize(joined: destination.dropFirst().utf8[...], changed: &ignored)
                if let (index, _):(Documentation.Index, Bool) = self.routing.resolve(path: path, overload: nil)
                {
                    resolved = index
                }
                else 
                {
                    throw ArticleError.undefinedSymbolLink(path, overload: nil)
                }
            }
            else 
            {
                path = .normalize(joined: destination.utf8[...], changed: &ignored)
                if      let first:[UInt8] = path.stem.first, 
                            first == self.biome.trunk(namespace: self.context.namespace),
                        let (index, _):(Documentation.Index, Bool) = self.routing.resolve(
                            namespace: self.context.namespace, 
                            stem: path.stem.dropFirst(1), 
                            leaf: path.leaf, 
                            overload: nil)
                {
                    resolved = index 
                }
                else if let (index, _):(Documentation.Index, Bool) = self.routing.resolve(
                            namespace: self.context.namespace, 
                            stem: path.stem[...], 
                            leaf: path.leaf, 
                            overload: nil)
                {
                    resolved = index 
                }
                else 
                {
                    throw ArticleError.undefinedSymbolLink(path, overload: nil)
                }
            }
            if case .ambiguous = resolved 
            {
                throw ArticleError.ambiguousSymbolLink(path, overload: nil)
            }
            return resolved
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

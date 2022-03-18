import Markdown
import StructuredDocument 
import HTML

enum MarkdownDiagnostic:Error 
{
    case unsupported(markup:Markup)
    case missingImageSource
    case missingLinkDestination
    case missingSymbolLinkDestination
    
    struct Renderer 
    {
        typealias Element = HTML.Element<Never>
        
        let biome:Biome 
        let routing:Documentation.RoutingTable
        
        var errors:[MarkdownDiagnostic]
        
        init(biome:Biome, routing:Documentation.RoutingTable)
        {
            self.biome      = biome 
            self.routing    = routing
            self.errors     = []
        }
        
        mutating 
        func render(comment:String) -> (head:Element?, body:[Element])
        {
            guard !comment.isEmpty 
            else 
            {
                return (nil, [])
            }
            let document:Markdown.Document = .init(parsing: comment)
            var blocks:LazyMapSequence<MarkupChildren, BlockMarkup>.Iterator = 
                document.blockChildren.makeIterator()
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
                body.reserveCapacity(document.childCount - 1)
            }
            else 
            {
                head = nil 
                body = [self.render(block: first, rank: 1)]
                body.reserveCapacity(document.childCount)
            }
            while let next:BlockMarkup = blocks.next()
            {
                body.append(self.render(block: next, rank: 1))
            }
            return (head, body)
        }
        
        // general 
        mutating 
        func render(document:Markdown.Document, rank:Int = 0) -> Element 
        {
            Element[.main]
            {
                for block:any BlockMarkup in document.blockChildren 
                {
                    self.render(block: block, rank: rank)
                }
            }
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
                self.errors.append(.unsupported(markup: unsupported))
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
            if case nil = image.source
            {
                self.errors.append(.missingImageSource)
            }
            return Element[.figure]
            {
                Element[.img]
                {
                    if let source:String = image.source 
                    {
                        (source, as: HTML.Src.self)
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
            guard let target:String = link.destination
            else 
            {
                self.errors.append(.missingLinkDestination)
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
        func render(symbollink link:SymbolLink) -> Element
        {
            guard let path:String = link.destination
            else 
            {
                self.errors.append(.missingSymbolLinkDestination)
                return Element[.code] { "<empty symbol path>" }
            }
            return Element[.code]
            {
                path
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
                return self.render(symbollink: link)
                
            case let unsupported: 
                self.errors.append(.unsupported(markup: unsupported))
                return Element[.div]
                {
                    "(unsupported inline markdown node '\(type(of: unsupported))')"
                }
            }
        }
    }
}

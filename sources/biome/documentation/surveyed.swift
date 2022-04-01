import Markdown
import StructuredDocument
import HTML

extension Documentation 
{
    enum EntraptaDirectiveError:Error
    {
        case emptyPathArgument
        case unexpectedPathArgument
    }
    public
    enum Format:String, Decodable
    {
        /// entrapta format 
        case entrapta
        
        /// lorentey’s `swift-collections` format
        // case collections
        
        /// nate cook’s `swift-algorithms` format
        // case algorithms 
        
        /// apple’s DocC format
        case docc
    }
    struct Metadata 
    {        
        var errors:[DirectiveArgumentText.ParseError]
        var path:[String]
        var format:Format
        var imports:Set<Biome.Module.ID> 
        
        var noTitle:Bool
        
        init(format:Format, directives:[BlockDirective])
        {
            self.errors = []
            self.path = []
            self.format = format 
            self.imports = []
            
            self.noTitle = false
            
            let directives:[String: [BlockDirective]] = .init(grouping: directives, by: \.name)
            //let parameters:[String: [[DirectiveArgument]]] = directives.mapValues 
            //{
            //    $0.
            //}
            switch format 
            {
            case .entrapta: 
                // @notitle 
                if  let anything:[BlockDirective] = directives["notitle"], !anything.isEmpty
                {
                    self.noTitle = true
                }
                // @import(_:)
                if  let matches:[BlockDirective] = directives["import"]
                {
                    for invocation:BlockDirective in matches 
                    {
                        guard let imported:Substring = invocation.argumentText.segments.first?.trimmedText
                        else 
                        {
                            continue 
                        }
                        self.imports.insert(Biome.Module.ID.init(imported))
                    }
                }
                // @path(_:)
                if  let matches:[BlockDirective] = directives["path"],
                    let match:BlockDirective = matches.last
                {
                    self.path = match.argumentText.segments
                        .map(\.trimmedText)
                        .joined()
                        .split(separator: "/")
                        .map(String.init(_:))
                }
            case .docc: 
                break 
            }
        }
    }


    struct Surveyed 
    {
        enum Node 
        {
            case section(Heading, [Self])
            case block(any BlockMarkup)
        }
        enum Headline 
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
            
            func rendered() -> Element? 
            {
                guard case .explicit(let headline) = self
                else 
                {
                    return nil
                }
                // FIXME: we should really be populating an outer `errors`
                // array, but a compiler crash prevents this method 
                // from taking any `inout` arguments.
                return .bytes(utf8: Surveyed.render(recurring: headline, as: .h1).rendered(as: [UInt8].self))
            }
        }
        // private 
        // let directives:[BlockDirective]
        let metadata:Metadata
        
        let headline:Headline
        let nodes:[Node]
        
        var snippet:String 
        {
            self.summary?.plainText ?? ""
        }
        var summary:Paragraph? 
        {
            if case .block(let paragraph as Paragraph)? = self.nodes.first
            {
                return paragraph
            }
            else 
            {
                return nil
            }
        }
        
        // `level` may skip levels
        private 
        typealias StackFrame = (heading:Headline, nodes:[Node])
        
        init(markdown string:String, format:Format)
        {
            let root:Markdown.Document = .init(parsing: string, 
                options: [ .parseBlockDirectives, .parseSymbolLinks ])
            self.init(root: root, format: format)
        }
        private  
        init(root:Markdown.Document, format:Format)
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
                    
                    self.init(format: format, directives: directives, 
                        headline: stack.top.heading, nodes: stack.top.nodes)
                    return
                }
                directives.append(directive)
            }
            self.init(format: format, directives: directives, headline: .implicit, nodes: [])
        }
        private 
        init(format:Format, directives:[BlockDirective], 
            headline:Headline, nodes:[Node])
        {
            self.metadata = .init(format: format, directives: directives)
            self.headline = headline
            self.nodes = nodes
        }
        
        var master:UnresolvedLink?
        {
            guard case .explicit(let headline) = self.headline 
            else 
            {
                return nil 
            }
            var spans:LazyMapSequence<MarkupChildren, InlineMarkup>.Iterator = 
                headline.inlineChildren.makeIterator()
            guard   let owner:any InlineMarkup  = spans.next(), 
                    case nil                    = spans.next(), 
                let owner:SymbolLink    = owner as? SymbolLink,
                let owner:String        = owner.destination, !owner.isEmpty
            else 
            {
                return nil
            }
            switch self.metadata.format 
            {
            // FIXME
            case .entrapta, .docc:
                return .docc(normalizing: owner)
            }
        }
        
        func rendered(biome:Biome, routing:RoutingTable, greenzone:(namespace:Int, scope:[[UInt8]])?) 
            -> (Article<UnresolvedLink>.Content, UnresolvedLinkContext)
        {
            let context:UnresolvedLinkContext = routing.context(imports: self.metadata.imports, greenzone: greenzone)
            
            var renderer:Renderer = .init(format: self.metadata.format, biome: biome, routing: routing,
                context: context)
            // note: we *never* render the top-level heading. this will either be 
            // auto-generated (for owned symbols), or stored as plain text by the 
            // caller of this function.
            let summary:Article<UnresolvedLink>.Element?, 
                remaining:ArraySlice<Node>
            if let paragraph:Paragraph = self.summary
            {
                summary = renderer.render(span: paragraph, as: .p)
                remaining = self.nodes.dropFirst()
            }
            else 
            {
                summary = nil 
                remaining = self.nodes[...]
            }
            let rank:Int
            switch self.headline 
            {
            case .implicit: rank = 1
            case .explicit: rank = 0
            }
            var discussion:[Article<UnresolvedLink>.Element] = []
            for node:Node in remaining 
            {
                renderer.render(node: node, demotedBy: rank, into: &discussion)
            }
            
            if case .implicit = self.headline 
            {
                // this would be better done at the markup level, but swift-markdown 
                // has a terrible block parsing API :/
                discussion = Renderer._sift(discussion, errors: &renderer.errors)
            }
            let content:Article<UnresolvedLink>.Content = 
                .init(errors: renderer.errors, summary: summary, discussion: discussion)
            return (content, context)
        }
        // `RecurringInlineMarkup` is not a useful abstraction
        static 
        func render(recurring inline:any InlineMarkup) -> StaticElement
        {
            switch inline
            {
            case is LineBreak:
                return StaticElement[.br]
            case is SoftBreak:
                return StaticElement.text(escaped: " ")
            
            case let span as CustomInline: 
                return StaticElement.text(escaping: span.text)
            case let text as Text:
                return StaticElement.text(escaping: text.string)
            case let span as InlineHTML:
                return StaticElement.text(escaped: span.rawHTML)
            case let span as InlineCode: 
                return StaticElement[.code] { span.code }
            case let span as Emphasis:
                return Self.render(recurring: span, as: .em)
            case let span as Strikethrough:
                return Self.render(recurring: span, as: .s)
            case let span as Strong:
                return Self.render(recurring: span, as: .strong)
            case let image as Image: 
                return Self.flatten(recurring: image)
            case let link as Link: 
                return Self.flatten(recurring: link)
            case let link as SymbolLink: 
                return StaticElement[.code] { link.destination ?? "" }
            default: 
                fatalError("unreachable")
            }
        }
        private static 
        func render<Span>(recurring span:Span, as container:HTML.Container) -> StaticElement
            where Span:InlineContainer
        {
            StaticElement[container]
            {
                for span:any InlineMarkup in span.inlineChildren
                {
                    Self.render(recurring: span)
                }
            }
        }
        private static 
        func flatten<Span>(recurring span:Span) -> StaticElement
            where Span:InlineContainer
        {
            var bytes:[UInt8] = []
            for span:any InlineMarkup in span.inlineChildren
            {
                Self.render(recurring: span).rendered(into: &bytes)
            }
            return .bytes(utf8: bytes)
        }
    }
}

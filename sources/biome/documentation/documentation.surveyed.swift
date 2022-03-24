import Markdown

extension Documentation 
{
    enum EntraptaDirectiveError:Error
    {
        case emptyPathArgument
        case unexpectedPathArgument
    }
    enum Format 
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
        var stem:[[UInt8]]?
        {
            self.path.isEmpty ? nil : self.path.map { URI.encode(component: $0.utf8) }
        }
        
        var errors:[DirectiveArgumentText.ParseError]
        var path:[String]
        var format:Format
        var imports:Set<Biome.Module.ID> 
        
        init(format:Format, directives:[BlockDirective])
        {
            self.errors = []
            self.path = []
            self.format = format 
            self.imports = []
            
            let directives:[String: [BlockDirective]] = .init(grouping: directives, by: \.name)
            //let parameters:[String: [[DirectiveArgument]]] = directives.mapValues 
            //{
            //    $0.
            //}
            switch format 
            {
            case .entrapta: 
                // @import(_:)
                if  let matches:[BlockDirective] = directives["depends"]
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
    enum SurveyedNode 
    {
        case section(Heading, [Self])
        case block(any BlockMarkup)
    }
    enum SurveyedHeading 
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
    }
    struct Surveyed 
    {
        // private 
        // let directives:[BlockDirective]
        let metadata:Metadata
        
        let heading:SurveyedHeading
        let nodes:[SurveyedNode]
        
        // `level` may skip levels
        private 
        typealias StackFrame = (heading:SurveyedHeading, nodes:[SurveyedNode])
        
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
                        heading: stack.top.heading, nodes: stack.top.nodes)
                    return
                }
                directives.append(directive)
            }
            self.init(format: format, directives: directives, heading: .implicit, nodes: [])
        }
        private 
        init(format:Format, directives:[BlockDirective], 
            heading:SurveyedHeading, nodes:[SurveyedNode])
        {
            self.metadata = .init(format: format, directives: directives)
            self.heading = heading
            self.nodes = nodes
        }
        
        var master:UnresolvedLink?
        {
            guard case .explicit(let heading) = self.heading 
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
                remaining:ArraySlice<SurveyedNode>
            if case .block(let paragraph as Paragraph)? = self.nodes.first
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
            switch self.heading 
            {
            case .implicit: rank = 1
            case .explicit: rank = 0
            }
            var discussion:[Article<UnresolvedLink>.Element] = []
            for node:SurveyedNode in remaining 
            {
                renderer.render(node: node, demotedBy: rank, into: &discussion)
            }
            
            if case .implicit = self.heading 
            {
                // this would be better done at the markup level, but swift-markdown 
                // has a terrible block parsing API :/
                discussion = Renderer._sift(discussion, errors: &renderer.errors)
            }
            let content:Article<UnresolvedLink>.Content = 
                .init(errors: renderer.errors, summary: summary, discussion: discussion)
            return (content, context)
        }
    }
}

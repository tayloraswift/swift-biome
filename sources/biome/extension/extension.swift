import Markdown
import Resource 
import HTML

extension ListItem 
{
    func recognize<Keyword>(where keyword:(Substring) throws -> Keyword?) 
        rethrows -> (Keyword, [any BlockMarkup])?
    {
        var blocks:[any BlockMarkup] = .init(self.blockChildren)
        
        guard   let paragraph:any BlockMarkup = blocks.first, 
                let paragraph:Paragraph = paragraph as? Paragraph
        else 
        {
            return nil
        }
        
        let magic:Keyword
        var inline:[any InlineMarkup] = .init(paragraph.inlineChildren)
        // find the first colon among the first two inline elements 
        guard   let first:any InlineMarkup = inline.first
        else 
        {
            return nil 
        }
        if      let text:Text = first as? Text
        {
            // 'keyword: blah blah blah'
            let string:String = text.string 
            guard   let colon:String.Index = string.firstIndex(of: ":"), 
                    let keyword:Keyword = try keyword(string[..<colon])
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
                inline[0] = Text.init(String.init(remaining))
            }
            
            magic = keyword
        }
        else if let second:any InlineMarkup = inline.dropFirst().first, 
                let second:Text = second as? Text
        {
            // '`keyword`: blah blah blah'
            // failing example here: https://developer.apple.com/documentation/system/filedescriptor/duplicate(as:retryoninterrupt:)
            // apple docs just drop the parameter
            let string:Substring = second.string.drop(while: \.isWhitespace) 
            guard   case ":"? = string.first, 
                    let keyword:Keyword = try keyword(first.plainText[...])
            else 
            {
                return nil 
            }
            
            let remaining:Substring = string.dropFirst().drop(while: \.isWhitespace)
            if  remaining.isEmpty  
            {
                inline.removeFirst(2)
            }
            else 
            {
                inline.removeFirst()
                inline[0] = Text.init(String.init(remaining))
            }
            
            magic = keyword
        }
        else 
        {
            return nil
        }
        
        if inline.isEmpty 
        {
            blocks.removeFirst()
        }
        else 
        {
            blocks[0] = Paragraph.init(inline)
        }
        return (magic, blocks)
    }
}

extension Extension 
{
    enum Keyword
    {
        enum Aside:String 
        {
            case attention              = "attention"
            case author                 = "author"
            case authors                = "authors"
            case bug                    = "bug"
            case complexity             = "complexity"
            case copyright              = "copyright"
            case date                   = "date"
            case experiment             = "experiment"
            case important              = "important"
            case invariant              = "invariant"
            case mutatingVariant        = "mutatingvariant"
            case nonMutatingVariant     = "nonmutatingvariant"
            case note                   = "note"
            case postcondition          = "postcondition"
            case precondition           = "precondition"
            case remark                 = "remark"
            case requires               = "requires"
            case seeAlso                = "seealso"
            case since                  = "since"
            case `throws`               = "throws"
            case tip                    = "tip"
            case todo                   = "todo"
            case version                = "version"
            case warning                = "warning"
            
            init(_ markdown:Markdown.Aside.Kind)
            {
                switch markdown 
                {
                    case .attention:            self = .attention
                    case .author:               self = .author
                    case .authors:              self = .authors
                    case .bug:                  self = .bug
                    case .complexity:           self = .complexity
                    case .copyright:            self = .copyright
                    case .date:                 self = .date
                    case .experiment:           self = .experiment
                    case .important:            self = .important
                    case .invariant:            self = .invariant
                    case .mutatingVariant:      self = .mutatingVariant
                    case .nonMutatingVariant:   self = .nonMutatingVariant
                    case .note:                 self = .note
                    case .postcondition:        self = .postcondition
                    case .precondition:         self = .precondition
                    case .remark:               self = .remark
                    case .requires:             self = .requires
                    case .since:                self = .since
                    case .throws:               self = .throws
                    case .tip:                  self = .tip
                    case .todo:                 self = .todo
                    case .version:              self = .version
                    case .warning:              self = .warning
                }
            }
            
            var prose:String 
            {
                switch self 
                {
                    case .attention:            return "Attention"
                    case .author:               return "Author"
                    case .authors:              return "Authors"
                    case .bug:                  return "Bug"
                    case .complexity:           return "Complexity"
                    case .copyright:            return "Copyright"
                    case .date:                 return "Date"
                    case .experiment:           return "Experiment"
                    case .important:            return "Important"
                    case .invariant:            return "Invariant"
                    case .mutatingVariant:      return "Mutating Variant"
                    case .nonMutatingVariant:   return "Non-mutating Variant"
                    case .note:                 return "Note"
                    case .postcondition:        return "Postcondition"
                    case .precondition:         return "Precondition"
                    case .remark:               return "Remark"
                    case .requires:             return "Requires"
                    case .seeAlso:              return "See Also"
                    case .since:                return "Since"
                    case .throws:               return "Throws"
                    case .tip:                  return "Tip"
                    case .todo:                 return "To-do"
                    case .version:              return "Version"
                    case .warning:              return "Warning"
                }
            }
        }
        
        case parameters 
        case parameter(String) 
        case returns
        case aside(Aside)
        case other(String)
        
        init?<S>(_ string:S) where S:StringProtocol, S.SubSequence == Substring
        {
            if let aside:Aside = .init(rawValue: String.init(string.filter(\.isLetter)).lowercased())
            {
                self = .aside(aside)
                return
            }
            
            let words:[Substring] = string.split(whereSeparator: \.isWhitespace)
            
            guard let keyword:String = words.first?.lowercased()
            else 
            {
                return nil 
            }
            if words.count == 2 
            {
                if keyword == "parameter"
                {
                    self = .parameter(String.init(words[1]))
                }
                else 
                {
                    return nil 
                }
            }
            else if words.count == 1 
            {
                switch keyword
                {
                case "parameters":      self = .parameters
                case "returns":         self = .returns
                default:                self = .other(String.init(words[0]))
                }
            }
            else 
            {
                return nil
            }
        }
    }
    
    struct Sections 
    {
        var parameters:[(String, [any BlockMarkup])] = []
        var returns:[any BlockMarkup] = []
        
        init()
        {
            self.parameters = []
            self.returns = []
        }
        
        mutating 
        func recognize(nodes:[Node]) -> [Node]
        {
            var replaced:[Node] = []
            for node:Node in nodes 
            {
                switch node 
                {
                case .section(let heading, let children):
                    replaced.append(.section(heading, self.recognize(nodes: children)))
                case .block(let list as UnorderedList):
                    replaced.append(contentsOf: self.recognize(unordered: list))
                default:
                    replaced.append(node)
                }
            }
            return replaced
        }
        private mutating 
        func recognize(unordered:UnorderedList) -> [Node] 
        {
            var muggles:[Node] = []
            for item:ListItem in unordered.listItems 
            {
                guard case let (keyword, content)? = 
                    item.recognize(where: Keyword.init(_:))
                else 
                {
                    muggles.append(.block(item))
                    continue 
                }
                magic:
                switch keyword 
                {
                case .other(let unknown):
                    print("warning: unknown keyword '\(unknown)'")
                
                case .aside(let aside): 
                    muggles.append(.aside(aside, .init(item.blockChildren)))
                    continue 
                
                case .returns:
                    returns.append(contentsOf: content)
                    continue 
                
                case .parameter(let parameter):
                    parameters.append((parameter, content))
                    continue 
                
                case .parameters:
                    var group:[(String, [any BlockMarkup])] = []
                    for block:any BlockMarkup in content
                    {
                        guard let unordered:UnorderedList = block as? UnorderedList 
                        else 
                        {
                            // expected unordered list
                            break magic
                        }
                        for inner:ListItem in unordered.listItems
                        {
                            let recognized:(String, [any BlockMarkup])? = inner.recognize
                            {
                                $0.contains(where: \.isWhitespace) ? nil : String.init($0)
                            }
                            guard case let (parameter, content)? = recognized
                            else 
                            {
                                break magic
                            }
                            group.append((parameter, content))
                        }
                    }
                    parameters.append(contentsOf: group)
                    continue 
                }
                
                muggles.append(.block(item))
            }
            
            var fractured:[Node] = []
            var sublist:[ListItem] = []
            for muggle:Node in muggles 
            {
                if case .block(let item as ListItem) = muggle
                {
                    sublist.append(item)
                    continue 
                }
                else if !sublist.isEmpty
                {
                    fractured.append(.block(UnorderedList.init(sublist)))
                    sublist = []
                }
                fractured.append(muggle)
            }
            if !sublist.isEmpty
            {
                fractured.append(.block(UnorderedList.init(sublist)))
            }
            return fractured
        }
    }
}
struct Extension 
{
    enum Node 
    {
        case section(Heading, [Self])
        case block(any BlockMarkup)
        case aside(Keyword.Aside, [any BlockMarkup])
    }
    enum Headline 
    {
        case implicit
        case explicit(Heading)
        
        var rank:Int 
        {
            switch self
            {
            case .implicit: return 1
            case .explicit: return 0
            }
        }
        var level:Int 
        {
            switch self 
            {
            case .implicit:                 return 1 
            case .explicit(let heading):    return heading.level
            }
        }
        
        /* func rendered() -> Documentation.Element? 
        {
            guard case .explicit(let headline) = self
            else 
            {
                return nil
            }
            // FIXME: we should really be populating an outer `errors`
            // array, but a compiler crash prevents this method 
            // from taking any `inout` arguments.
            return .bytes(utf8: Extension.render(recurring: headline, as: .h1).rendered(as: [UInt8].self))
        } */
    }
    
    private(set)
    var metadata:Metadata
    
    let headline:Headline
    let nodes:[Node]
    var sections:Sections
    
    var snippet:String 
    {
        self.summary?.plainText ?? ""
    }
    private 
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
    
    init(from resource:Resource, name:String) 
    {
        // TODO: handle versioning
        switch resource.payload
        {
        case    .text   (let text,  type: _):
            self.init(markdown: text)
        case    .binary (let bytes, type: _):
            self.init(markdown: String.init(decoding: bytes, as: Unicode.UTF8.self))
        }
        if case nil = self.metadata.path
        {
            self.metadata.path = .init(last: name)
        }
    }
    init(markdown string:String)
    {
        let root:Markdown.Document = .init(parsing: string, 
            options: [ .parseBlockDirectives, .parseSymbolLinks ])
        self.init(root: root)
    }
    private  
    init(root:Markdown.Document)
    {
        // `level` may skip levels
        typealias StackFrame = (heading:Headline, nodes:[Node])
        
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
                
                self.init(directives: directives, 
                    headline: stack.top.heading, nodes: stack.top.nodes)
                return
            }
            directives.append(directive)
        }
        self.init(directives: directives, headline: .implicit, nodes: [])
    }
    private 
    init(directives:[BlockDirective], headline:Headline, nodes:[Node])
    {
        self.metadata = .init(directives: directives)
        self.headline = headline
        self.sections = .init()
        
        if case .implicit = self.headline 
        {
            self.nodes = self.sections.recognize(nodes: nodes)
        }
        else 
        {
            self.nodes = nodes
        }
    }
    
    var binding:String?
    {
        guard case .explicit(let headline) = self.headline 
        else 
        {
            return nil 
        }
        var spans:LazyMapSequence<MarkupChildren, InlineMarkup>.Iterator = 
            headline.inlineChildren.makeIterator()
        if  let owner:any InlineMarkup  = spans.next(), 
            case nil                    = spans.next(), 
            let owner:SymbolLink    = owner as? SymbolLink,
            let owner:String        = owner.destination, !owner.isEmpty
        {
            return owner
        }
        else 
        {
            return nil
        }
    }
    
    func render() -> Article.Template<String>
    {
        var renderer:Renderer = .init(rank: self.headline.rank)
        // note: we *never* render the top-level heading. this will either be 
        // auto-generated (for owned symbols), or stored as plain text by the 
        // caller of this function.
        let first:HTML.Element<String>?, 
            remaining:ArraySlice<Node>
        if let paragraph:Paragraph = self.summary
        {
            first = renderer.render(span: paragraph, as: .p)
            remaining = self.nodes.dropFirst()
        }
        else 
        {
            first = nil 
            remaining = self.nodes[...]
        }
        
        if case .implicit = self.headline 
        {
            renderer.append(sections: self.sections)
            renderer.append(nodes: remaining, under: "Overview", classes: "discussion")
        }
        else 
        {
            renderer.append(nodes: remaining)
        }
        let discussion:DOM.Template<String, [UInt8]> = .init(freezing: renderer.elements)
        let summary:DOM.Template<String, [UInt8]>
        if let first:HTML.Element<String> = first 
        {
            summary = .init(freezing: first)
        }
        else 
        {
            summary = .empty
        }
        return .init(errors: renderer.errors, summary: summary, discussion: discussion)
    }
    // `RecurringInlineMarkup` is not a useful abstraction
    /* private static 
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
    }  */
}

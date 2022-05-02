import Markdown
import StructuredDocument 
import HTML

extension Article
{
    enum LinkResolutionError:Error 
    {
        case ambiguous(UnresolvedLink)
        case undefined(UnresolvedLink)
    }
    enum RenderingError:Error 
    {
        case emptyImageSource
        case emptyLinkDestination
        
        case unsupportedMarkdown(String)
        
        // TODO: rework these
        case unsupportedMagicKeywords([String]) 
        
        case emptyReturnsField
        case emptyParameterField(name:String?) 
        case emptyParameterList
        
        case multipleReturnsFields([Rendered<UnresolvedLink>.Element], [Rendered<UnresolvedLink>.Element])
        
        case invalidParameterListItem(Rendered<UnresolvedLink>.Element)
        case invalidParameterList(Rendered<UnresolvedLink>.Element)
        case multipleParameterLists(Rendered<UnresolvedLink>.Element, Rendered<UnresolvedLink>.Element)
        
        /* var description:String 
        {
            switch self 
            {
            case .empty(parameter: nil):
                return "comment 'parameters' is completely empty"
            case .empty(parameter: let name?):
                return "comment 'parameter \(name)' is completely empty"
            case .invalidListItem(let item):
                return 
                    """
                    comment 'parameters' contains invalid list item:
                    '''
                    \(item.rendered)
                    '''
                    """
            case .invalidList(let block):
                return 
                    """
                    comment 'parameters' must contain a list, encountered:
                    '''
                    \(block.rendered)
                    '''
                    """
            case .multipleLists(let blocks):
                return 
                    """
                    comment 'parameters' must contain exactly one list, encountered:
                    '''
                    \(blocks.map(\.rendered).joined(separator: "\n"))
                    '''
                    """
            }
        } */
    }
    struct Renderer 
    {
        typealias Element = Rendered<UnresolvedLink>.Element 
        
        private 
        enum CodeBlockLanguage 
        {
            case swift 
            case plain
        }
        
        var errors:[Error]
        
        init()
        {
            self.errors = []
        }
        mutating 
        func render(node:Surveyed.Node, demotedBy rank:Int, into elements:inout [Element])
        {
            switch node 
            {
            case .block(let block): 
                // rank should not matter
                elements.append(self.render(block: block, demotedBy: rank))
            case .section(let heading, let children):
                elements.append(self.render(heading: heading, demotedBy: rank))
                for node:Surveyed.Node in children 
                {
                    self.render(node: node, demotedBy: rank, into: &elements)
                }
            }
        }

        private mutating 
        func render(aside:Aside, demotedBy rank:Int) -> Element 
        {
            Element[.aside]
            {
                [aside.kind.rawValue.lowercased()]
            }
            content:
            {
                Element[.h3]
                {
                    switch aside.kind 
                    {
                    case .note:                 "Note"
                    case .tip:                  "Tip"
                    case .important:            "Important"
                    case .experiment:           "Experiment"
                    case .warning:              "Warning"
                    case .attention:            "Attention"
                    case .author:               "Author"
                    case .authors:              "Authors"
                    case .bug:                  "Bug"
                    case .complexity:           "Complexity"
                    case .copyright:            "Copyright"
                    case .date:                 "Date"
                    case .invariant:            "Invariant"
                    case .mutatingVariant:      "Mutating variant"
                    case .nonMutatingVariant:   "Non-mutating variant"
                    case .postcondition:        "Postcondition"
                    case .precondition:         "Precondition"
                    case .remark:               "Remark"
                    case .requires:             "Requires"
                    case .since:                "Since"
                    case .todo:                 "To-do"
                    case .version:              "Version"
                    case .`throws`:             "Throws"
                    }
                }
                for block:any BlockMarkup in aside.content 
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
                return self.render(aside: Aside.init(aside), demotedBy: rank)
            
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
                return Self.highlight(block: block.code, 
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
                self.errors.append(RenderingError.unsupportedMarkdown(unsupported.debugDescription()))
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
            /* return Element[.h2]
            {
                ("subsection-\(index)", as: HTML.ID.self)
            }
            content: 
            {
                Element[.span] 
                {
                    ["subsection-anchor"]
                } 
                content: 
                {
                    Element.link("\(index)", to: "#subsection-\(index)")
                }
                headings().joined() as FlattenSequence<[[Element]]>
            } */
            return self.render(span: heading, as: level)
        }
        private static
        func highlight(block code:String, as language:CodeBlockLanguage) -> Element 
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
                    ["\(language)"]
                }
                content:
                {
                    fragments
                }
            }
        }
        private static
        func highlight(inline code:String, as language:CodeBlockLanguage) -> Element 
        {
            switch language 
            {
            case .plain: 
                return Element[.code] { ["plain"] } content: { code }
            case .swift:
                return Element[.code] { ["swift"] } content:
                {
                    for (text, highlight):(String, SwiftHighlight) in SwiftHighlight.highlight(code)
                    {
                        Element.highlight(text, highlight)
                    }
                }
            }
        }
        private 
        func highlight(inline link:Link) -> Element?
        {
            let spans:[any InlineMarkup] = .init(link.inlineChildren)
            guard   let span:any InlineMarkup = spans.first, spans.count == 1,
                    let span:InlineCode = span as? InlineCode 
            else 
            {
                return nil 
            }
            return Self.highlight(inline: span.code, as: .swift)
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
        mutating 
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
                        let _:Void = self.errors.append(RenderingError.emptyImageSource)
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
                if  let code:Element = self.highlight(inline: link)
                {
                    return code
                }
                else 
                {
                    self.errors.append(RenderingError.emptyLinkDestination)
                    return self.render(span: link, as: .span)
                }
            }
            parsing:
            if let colon:String.Index = string.firstIndex(of: ":"), string[..<colon] == "doc"
            {
                let start:String.Index = string.index(after: colon)
                if  string[start...].starts(with: "//")
                {
                    Swift.print("skipped resolving invalid documentation link '\(string)'")
                    break parsing 
                }
                return .anchor(id: .doc(String.init(string[start...])))
            }
            
            return self.present(externalLink: link.inlineChildren.map
            {
                self.render(inline: $0)
            }, to: string)
        }
        private mutating 
        func render(link:SymbolLink) -> Element
        {
            if let string:String = link.destination
            {
                return .anchor(id: .fenced(string))
            }
            else 
            {
                self.errors.append(RenderingError.emptyLinkDestination)
                return Element[.code] { "<empty symbol path>" }
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
                self.errors.append(RenderingError.unsupportedMarkdown(unsupported.debugDescription()))
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
        
        static 
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
                                throw RenderingError.multipleReturnsFields(returns, section)
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
                    throw RenderingError.unsupportedMagicKeywords(keywords)
                }
                return .parameters(try Self.parameters(in: content))
                
            case "parameter": 
                guard keywords.count == 2 
                else 
                {
                    throw RenderingError.unsupportedMagicKeywords(keywords)
                }
                let name:String = keywords[1]
                if content.isEmpty
                {
                    throw RenderingError.emptyParameterField(name: name)
                } 
                return .parameters([(name, content)])
            
            case "returns":
                guard keywords.count == 1 
                else 
                {
                    throw RenderingError.unsupportedMagicKeywords(keywords)
                }
                if content.isEmpty
                {
                    throw RenderingError.emptyReturnsField
                }
                return .returns(content)
            
            case "tip", "note", "info", "warning", "throws", "important", "precondition", "complexity":
                guard keywords.count == 1 
                else 
                {
                    throw RenderingError.unsupportedMagicKeywords(keywords)
                }
                return .aside(Element[.aside]
                {
                    [keyword]
                }
                content:
                {
                    Element[.h3]
                    {
                        keyword
                    }
                    
                    content
                })
                
            default:
                throw RenderingError.unsupportedMagicKeywords(keywords)
            }
        }
        
        private static
        func parameters(in content:[Element]) throws -> [(name:String, comment:[Element])]
        {
            guard let first:Element = content.first 
            else 
            {
                throw RenderingError.emptyParameterList
            }
            // look for a nested list 
            guard case .container(.ul, attributes: _, content: let items) = first 
            else 
            {
                throw RenderingError.invalidParameterList(first)
            }
            if let second:Element = content.dropFirst().first
            {
                throw RenderingError.multipleParameterLists(first, second)
            }
            
            var parameters:[(name:String, comment:[Element])] = []
            for item:Element in items
            {
                guard   case .container(.li, attributes: _, content: let content) = item, 
                        let (keywords, content):([String], [Element]) = Self.keywords(prefixing: content), 
                        let name:String = keywords.first, keywords.count == 1
                else 
                {
                    throw RenderingError.invalidParameterListItem(item)
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

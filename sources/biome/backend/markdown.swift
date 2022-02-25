import Markdown 
import StructuredDocument

extension Biome
{
    func render(markdown:Markdown.Markup) -> Frontend
    {
        switch markdown 
        {
        case let node as Markdown.Document: 
            return Frontend[.main]
            {
                node.children.map(self.render(markdown:))
            }
        case let node as Markdown.BlockQuote: 
            return Frontend[.blockquote]
            {
                node.children.map(self.render(markdown:))
            }
        case let node as Markdown.CodeBlock: 
            return self.renderNotebook(highlighting: node.code)
        case let node as Markdown.Heading: 
            let container:StructuredDocument.Document.HTML.Container 
            switch node.level 
            {
            case 1:     container = .h2
            case 2:     container = .h3
            case 3:     container = .h4
            case 4:     container = .h5
            default:    container = .h6
            }
            return Frontend[container]
            {
                node.children.map(self.render(markdown:))
            }
        case is Markdown.ThematicBreak: 
            return Frontend[.hr]
        case let node as Markdown.HTMLBlock: 
            return .text(escaped: node.rawHTML)
        case let node as Markdown.ListItem: 
            return Frontend[.li]
            {
                node.children.map(self.render(markdown:))
            }
        case let node as Markdown.OrderedList: 
            return Frontend[.ol]
            {
                node.children.map(self.render(markdown:))
            }
        case let node as Markdown.UnorderedList: 
            return Frontend[.ul]
            {
                node.children.map(self.render(markdown:))
            }
        case let node as Markdown.Paragraph: 
            return Frontend[.p]
            {
                node.children.map(self.render(markdown:))
            }
        case is Markdown.BlockDirective: 
            return Frontend[.div]
            {
                "(unsupported block directive)"
            }
        case let node as Markdown.InlineCode: 
            return Frontend[.code]
            {
                node.code
            }
        case let node as Markdown.CustomInline: 
            return .text(escaping: node.text)
        case let node as Markdown.Emphasis: 
            return Frontend[.em]
            {
                node.children.map(self.render(markdown:))
            }
        case let node as Markdown.Image: 
            return self.renderImage(source: node.source, alt: node.children.map(self.render(markdown:)), title: node.title)
        case let node as Markdown.InlineHTML: 
            return .text(escaped: node.rawHTML)
        case is Markdown.LineBreak: 
            return Frontend[.br]
        case let node as Markdown.Link: 
            return self.renderLink(to: node.destination, node.children.map(self.render(markdown:)))
        case is Markdown.SoftBreak: 
            return .text(escaped: " ")
        case let node as Markdown.Strong: 
            return Frontend[.strong]
            {
                node.children.map(self.render(markdown:))
            }
        case let node as Markdown.Text: 
            return .text(escaping: node.string)
        case let node as Markdown.Strikethrough: 
            return Frontend[.s]
            {
                node.children.map(self.render(markdown:))
            }
        case let node as Markdown.Table: 
            return Frontend[.table]
            {
                node.children.map(self.render(markdown:))
            }
        case let node as Markdown.Table.Row: 
            return Frontend[.tr]
            {
                node.children.map(self.render(markdown:))
            }
        case let node as Markdown.Table.Head: 
            return Frontend[.thead]
            {
                node.children.map(self.render(markdown:))
            }
        case let node as Markdown.Table.Body: 
            return Frontend[.tbody]
            {
                node.children.map(self.render(markdown:))
            }
        case let node as Markdown.Table.Cell: 
            return Frontend[.td]
            {
                node.children.map(self.render(markdown:))
            }
        case let node as Markdown.SymbolLink: 
            return self.renderSymbolLink(to: node.destination)
            
        case let node: 
            return Frontend[.div]
            {
                "(unsupported markdown node '\(type(of: node))')"
            }
        }
    }
    
    // expected parameters is unreliable, not available for subscripts
    func render(markdown string:String, diagnostics:inout Diagnostics) -> Comment
    {
        var comment:Comment = .init() 
        
        let document:Markdown.Document      = .init(parsing: string)
        
        if diagnostics.uri == "/reference/swift-system/systempackage/filepath"
        {
            print(document.debugDescription())
        }
        
        let blocks:[Markdown.BlockMarkup]   = .init(document.blockChildren)
        let body:ArraySlice<Markdown.BlockMarkup>
        if  let first:Markdown.BlockMarkup  = blocks.first, 
                first is Markdown.Paragraph
        {
            comment.head = self.render(markdown: first)
            body = blocks.dropFirst()
        }
        else 
        {
            comment.head = nil 
            body = blocks[...]
        }
        // filter out top-level ‘ul’ blocks, since they may be special 
        // var parameters:[String: [Biome.Frontend]] = [:]
        comment.returns = []
        comment.body = []
        comment.complexity = nil
        comment.parameters = []
        for block:Markdown.BlockMarkup in body 
        {
            guard let list:Markdown.UnorderedList = block as? Markdown.UnorderedList 
            else 
            {
                comment.body.append(self.render(markdown: block))
                continue 
            }
            var ignored:[Markdown.ListItem] = []
            for item:Markdown.ListItem in list.listItems 
            {
                guard   let (keywords, content):([String], [Markdown.BlockMarkup]) = Comment.keywords(prefixing: item, plain: true), 
                        let  keyword:String = keywords.first
                else 
                {
                    ignored.append(item)
                    continue 
                }
                switch (keyword.lowercased(), keywords.dropFirst().first)
                {
                case    ("tip", nil), 
                        ("note", nil), 
                        ("info", nil), 
                        ("warning", nil), 
                        ("throws", nil), 
                        ("important", nil), 
                        ("precondition", nil): 
                    comment.body.append(Biome.Frontend[.aside]
                    {
                        [keyword]
                    }
                    content:
                    {
                        Biome.Frontend[.h2]
                        {
                            keyword
                        }
                        content.map(self.render(markdown:))
                    })
                case ("complexity", nil): 
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
                    comment.body.append(Biome.Frontend[.aside]
                    {
                        [keyword]
                    }
                    content:
                    {
                        Biome.Frontend[.h2]
                        {
                            keyword
                        }
                        content.map(self.render(markdown:))
                    })
                case ("returns", nil): 
                    if content.isEmpty
                    {
                        diagnostics.warning("'returns' section is completely empty")
                    }
                    if !comment.returns.isEmpty 
                    {
                        diagnostics.warning("detected multiple 'returns' sections, only the last will be used")
                    }
                    comment.returns = content.map(self.render(markdown:))
                case ("parameters", nil): 
                    guard let list:Markdown.BlockMarkup = content.first 
                    else 
                    {
                        diagnostics.warning("'parameters' section is completely empty")
                        continue 
                    }
                    // look for a nested list 
                    guard let list:Markdown.UnorderedList = list as? Markdown.UnorderedList
                    else 
                    {
                        fatalError("'parameters' section does not contain a sublist")
                    }
                    
                    for item:Markdown.ListItem in list.listItems 
                    {
                        guard   let (keywords, content):([String], [Markdown.BlockMarkup]) = Comment.keywords(prefixing: item, plain: false), 
                                let  name:String = keywords.first, keywords.dropFirst().isEmpty
                        else 
                        {
                            fatalError("'parameters' section does not contain well-formed parameter comments: \(item.debugDescription())")
                        }
                        comment.parameters.append((name, content.map(self.render(markdown:))))
                    }
                case ("parameter", let name?): 
                    if keywords.count > 2 
                    {
                        diagnostics.warning("ignored trailing keywords after 'parameter' heading (parameter '\(name)')")
                    }
                    if content.isEmpty
                    {
                        diagnostics.warning("'parameter' section is completely empty (parameter '\(name)')")
                    } 
                    comment.parameters.append((name, content.map(self.render(markdown:))))
                default: 
                    diagnostics.warning("unrecognized keywords: \(keywords)")
                    ignored.append(item)
                    continue 
                }
            }
            guard ignored.isEmpty 
            else 
            {
                comment.body.append(self.render(markdown: Markdown.UnorderedList.init(ignored)))
                continue 
            }
        }
        
        /* comment.parameters = []
        for parameter:Biome.Symbol.Parameter in expected 
        {
            let name:String = parameter.name ?? parameter.label
            let comment:[Biome.Frontend]? = parameters.removeValue(forKey: name)
            if case nil = comment 
            {
                print("warning: missing comment for parameter \(parameter)")
            }
            comment.parameters.append((name, comment ?? []))
        }
        if !parameters.isEmpty 
        {
            print("warning: ignored extraneous parameters \(parameters)")
        } */
        return comment
    }
}
extension Biome 
{
    struct Comment 
    {
        var head:Frontend?, 
            body:[Frontend]
        var parameters:[(name:String, comment:[Frontend])]
        var returns:[Frontend]
        var complexity:Complexity?
        
        init() 
        {
            self.head = nil 
            self.body = []
            self.parameters = []
            self.returns = []
            self.complexity = nil
        }
        
        static 
        func keywords(prefixing item:Markdown.ListItem, plain:Bool) -> (keywords:[String], content:[Markdown.BlockMarkup])?
        {
            var outer:LazyMapSequence<Markdown.MarkupChildren, Markdown.BlockMarkup>.Iterator = 
               item.blockChildren.makeIterator()
            guard   let paragraph:Markdown.BlockMarkup = outer.next(),
                    let paragraph:Markdown.Paragraph = paragraph as? Markdown.Paragraph
            else 
            {
                return nil 
            }
            var inner:LazyMapSequence<Markdown.MarkupChildren, Markdown.InlineMarkup>.Iterator = 
                paragraph.inlineChildren.makeIterator()
            guard let first:Markdown.InlineMarkup = inner.next()
            else 
            {
                return nil 
            }
            let string:String 
            let colon:String.Index
            if  let first:Markdown.Text = first as? Markdown.Text, 
                let index:String.Index  = first.string.firstIndex(of: ":")
            {
                string  = first.string 
                colon   = index 
            }
            // failing example here: https://developer.apple.com/documentation/system/filedescriptor/duplicate(as:retryoninterrupt:)
            // apple docs just drop the parameter
            else if !plain, 
                let first:Markdown.InlineCode = first as? Markdown.InlineCode 
            {
                string  = first.code 
                colon   = string.firstIndex(of: ":") ?? string.endIndex
                print("warning: parameter name '`\(string)`' does not need backticks")
            }
            else 
            {
                return nil 
            }
            let keywords:[String] = string.prefix(upTo: colon)
                .split(whereSeparator: \.isWhitespace)
                .map(String.init(_:))
            let remaining:Substring = string[colon...].dropFirst().drop(while: \.isWhitespace)
            guard remaining.isEmpty 
            else 
            {
                let inline:[Markdown.InlineMarkup] = [Markdown.Text.init(String.init(remaining))] + inner
                let children:[Markdown.BlockMarkup] = [Markdown.Paragraph.init(inline)] + outer
                return (keywords, children)
            }
            if let next:Markdown.InlineMarkup = inner.next()
            {
                let children:[Markdown.BlockMarkup] = [Markdown.Paragraph.init([next] + inner)] + outer
                return (keywords, children)
            }
            else 
            {
                return (keywords, .init(outer))
            }
        }
    }
}

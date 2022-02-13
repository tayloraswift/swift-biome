import Markdown 
import StructuredDocument

extension StructuredDocument.Document.Element where Domain == StructuredDocument.Document.HTML
{
    init(markdown:Markdown.Markup, 
        symbol:(_ destination:String?) -> Self, 
        link:(_ destination:String?, _ content:[Self]) -> Self, 
        image:(_ source:String?, _ alt:[Self], _ title:String?) -> Self, 
        highlight:(_ code:String) -> Self) 
    {
        func render(markdown:Markdown.Markup) -> Self 
        {
            .init(markdown: markdown, symbol: symbol, link: link, image: image, highlight: highlight)
        }
        
        switch markdown 
        {
        case let node as Markdown.Document: 
            self = Self[.main]
            {
                node.children.map(render(markdown:))
            }
        case let node as Markdown.BlockQuote: 
            self = Self[.blockquote]
            {
                node.children.map(render(markdown:))
            }
        case let node as Markdown.CodeBlock: 
            self = highlight(node.code)
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
            self = Self[container]
            {
                node.children.map(render(markdown:))
            }
        case is Markdown.ThematicBreak: 
            self = Self[.hr]
        case let node as Markdown.HTMLBlock: 
            self = .text(escaped: node.rawHTML)
        case let node as Markdown.ListItem: 
            self = Self[.li]
            {
                node.children.map(render(markdown:))
            }
        case let node as Markdown.OrderedList: 
            self = Self[.ol]
            {
                node.children.map(render(markdown:))
            }
        case let node as Markdown.UnorderedList: 
            self = Self[.ul]
            {
                node.children.map(render(markdown:))
            }
        case let node as Markdown.Paragraph: 
            self = Self[.p]
            {
                node.children.map(render(markdown:))
            }
        case is Markdown.BlockDirective: 
            self = Self[.div]
            {
                "(unsupported block directive)"
            }
        case let node as Markdown.InlineCode: 
            self = Self[.code]
            {
                node.code
            }
        case let node as Markdown.CustomInline: 
            self = .text(escaping: node.text)
        case let node as Markdown.Emphasis: 
            self = Self[.em]
            {
                node.children.map(render(markdown:))
            }
        case let node as Markdown.Image: 
            self = image(node.source, node.children.map(render(markdown:)), node.title)
        case let node as Markdown.InlineHTML: 
            self = .text(escaped: node.rawHTML)
        case is Markdown.LineBreak: 
            self = Self[.br]
        case let node as Markdown.Link: 
            self = link(node.destination, node.children.map(render(markdown:)))
        case is Markdown.SoftBreak: 
            self = .text(escaped: " ")
        case let node as Markdown.Strong: 
            self = Self[.strong]
            {
                node.children.map(render(markdown:))
            }
        case let node as Markdown.Text: 
            self = .text(escaping: node.string)
        case let node as Markdown.Strikethrough: 
            self = Self[.s]
            {
                node.children.map(render(markdown:))
            }
        case let node as Markdown.Table: 
            self = Self[.table]
            {
                node.children.map(render(markdown:))
            }
        case let node as Markdown.Table.Row: 
            self = Self[.tr]
            {
                node.children.map(render(markdown:))
            }
        case let node as Markdown.Table.Head: 
            self = Self[.thead]
            {
                node.children.map(render(markdown:))
            }
        case let node as Markdown.Table.Body: 
            self = Self[.tbody]
            {
                node.children.map(render(markdown:))
            }
        case let node as Markdown.Table.Cell: 
            self = Self[.td]
            {
                node.children.map(render(markdown:))
            }
        case let node as Markdown.SymbolLink: 
            self = symbol(node.destination)
            
        case let node: 
            self = Self[.div]
            {
                "(unsupported markdown node '\(type(of: node))')"
            }
        }
    }
}
extension Entrapta 
{
    static 
    func render(markdown string:String, 
        symbol:(_ destination:String?) -> Graph.Frontend, 
        link:(_ destination:String?, _ content:[Graph.Frontend]) -> Graph.Frontend, 
        image:(_ source:String?, _ alt:[Graph.Frontend], _ title:String?) -> Graph.Frontend,
        highlight:(_ code:String) -> Graph.Frontend) 
        -> (head:Graph.Frontend?, body:[Graph.Frontend])
    {
        func render(markdown:Markdown.Markup) -> Graph.Frontend 
        {
            .init(markdown: markdown, symbol: symbol, link: link, image: image, highlight: highlight)
        }
        
        let document:Markdown.Document  = .init(parsing: string)
        let blocks:[Markdown.Markup]    = .init(document.children)
        if  let head:Markdown.Markup    = blocks.first, head is Markdown.Paragraph
        {
            return (render(markdown: head), document.children.dropFirst().map(render(markdown:)))
        }
        else 
        {
            return (nil, document.children.map(render(markdown:)))
        }
    }
}
/* import Grammar 

extension Grammar.Encoding where Terminal == Character
{
    public 
    enum Grapheme 
    {
        public
        enum Asterisk:Grammar.TerminalSequence
        {
            @inlinable public static 
            var literal:CollectionOfOne<Character> { .init("*") }
        }
        public
        enum Equals:Grammar.TerminalSequence
        {
            @inlinable public static 
            var literal:CollectionOfOne<Character> { .init("=") }
        }
        public
        enum Hashtag:Grammar.TerminalSequence
        {
            @inlinable public static 
            var literal:CollectionOfOne<Character> { .init("#") }
        }
        public
        enum Hyphen:Grammar.TerminalSequence
        {
            @inlinable public static 
            var literal:CollectionOfOne<Character> { .init("-") }
        }
        public
        enum Newline:Grammar.TerminalSequence
        {
            @inlinable public static 
            var literal:CollectionOfOne<Character> { .init("\n") }
        }
        public
        enum Underscore:Grammar.TerminalSequence
        {
            @inlinable public static 
            var literal:CollectionOfOne<Character> { .init("_") }
        }
    }
}
extension Grammar 
{
    enum Count<Rule>:ParsingRule where Rule:ParsingRule, Rule.Construction == Void
    {
        typealias Location = Rule.Location
        typealias Terminal = Rule.Terminal
        
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> Int 
            where   Diagnostics:ParsingDiagnostics, 
                    Diagnostics.Source.Index == Location, Diagnostics.Source.Element == Terminal
        {
            try input.parse(as: Rule.self)
            var count:Int = 1 
            while let _:Void = input.parse(as: Rule?.self) 
            {
                count += 1
            }
            return count
        }
    } 
}

enum Markdown 
{
    enum Block
    {
        enum Line 
        {
            case fence(language:String?)
            case rule(level:Int)
            case heading(level:Int, String)
            case item(indent:Int, counter:Int?, String)
            case text(indent:(quotient:Int, remainder:Int), String)
            case columns([String?])
            case empty 
            
            enum Rule<Location> 
            {
                typealias Grapheme  = Grammar.Encoding<Location, Character>.Grapheme
                typealias Digit<T>  = Grammar.Digit<Location, Character, T>.Grapheme
            }
        }
        
        enum Rule<Location> 
        {
        }
    }
    
    static 
    func blocks(assembling lines:Block.Line) -> [Block]
    {
        
    }
}
extension Markdown.Block.Line.Rule:ParsingRule 
{
    enum HorizontalRule:ParsingRule
    {
        typealias Terminal = Character 
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> Int
            where   Diagnostics:ParsingDiagnostics, 
                    Diagnostics.Source.Index == Location, Diagnostics.Source.Element == Terminal
        {
            if let _:(Void, Void, Void) = 
                try? input.parse(as: (Grapheme.Equals, Grapheme.Equals, Grapheme.Equals).self)
            {
                input.parse(as: Grapheme.Equals.self, in: Void.self)
                return 2
            }
            else 
            {
                try input.parse(as: (Grapheme.Hyphen, Grapheme.Hyphen, Grapheme.Hyphen).self)
                input.parse(as: Grapheme.Hyphen.self, in: Void.self)
                return 3
            }
        }
    }
    enum ListDecorator:ParsingRule
    {
        typealias Terminal = Character 
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> Int?
            where   Diagnostics:ParsingDiagnostics, 
                    Diagnostics.Source.Index == Location, Diagnostics.Source.Element == Terminal
        {
            if  let _:Void =    
                input.parse(as: Grapheme.Asterisk?.self) ?? 
                input.parse(as: Grapheme.Hyphen?.self) ?? 
                input.parse(as: Grapheme.Plus?.self)
            {
                try input.parse(as: Grapheme.Space.self)
                return nil
            }
            let counter:Int = try input.parse(as: Grammar.UnsignedIntegerLiteral<Digit<Int>.Decimal>.self)
            try input.parse(as: Grapheme.Period.self)
            try input.parse(as: Grapheme.Space.self)
            return counter 
        }
    }
    
    typealias Terminal = Character 
    static 
    func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) -> Markdown.Block.Line
        where   Diagnostics:ParsingDiagnostics, 
                Diagnostics.Source.Index == Location, Diagnostics.Source.Element == Terminal
    {
        if  let _:Void = input.parse(as: Grapheme.Space?.self),
            let _:Void = input.parse(as: Grapheme.Space?.self),
            let _:Void = input.parse(as: Grapheme.Space?.self),
            let _:Void = input.parse(as: Grapheme.Space?.self)
        {
            // indented 
            let suffix:Diagnostics.Source.Subsequence = input.suffix()
            return suffix.allSatisfy(\.isWhitespace) ? .empty : .indented(String.init(suffix))
        }
        if let level:Int = input.parse(as: Grammar.Count<Grapheme.Hashtag>?.self)
        {
            // strip leading and trailing whitespace
            input.parse(as: Grapheme.Space.self, in: Void.self)
            var suffix:String   = String.init(input.suffix())
            while case true?    = suffix.last?.isWhitespace
            {
                suffix.removeLast()
            }
            return .heading(level: level, suffix)
        }
        else if let level:Int = input.parse(as: HorizontalRule?.self)
        {
            input.parse(as: Grapheme.Space.self, in: Void.self)
            return .rule(level: level)
        }
        else if let counter:Int? = try? input.parse(as: ListDecorator.self)
        {
            // strip leading and trailing whitespace
            input.parse(as: Grapheme.Space.self, in: Void.self)
            var suffix:String   = String.init(input.suffix())
            while case true?    = suffix.last?.isWhitespace
            {
                suffix.removeLast()
            }
            return .item(counter: counter, suffix)
        }
        else 
        {
            // strip trailing whitespace
            var suffix:String   = String.init(input.suffix())
            while case true?    = suffix.last?.isWhitespace
            {
                suffix.removeLast()
            }
            return .text(suffix)
        }
    }
}
extension Markdown.Block.Rule
{
    typealias Terminal = Markdown.Block.Line

    //  Heading       ::= <text> + <rule>
    //                  | <heading>
    //  Paragraph     ::= <text> +
    //  Code          ::= <indented> ( <empty> * <indented> + ) *
    //                  | <fence> ( ... ) <fence> 
    //  List          ::= <item>
    enum Block:ParsingRule 
    {
        enum Line
        {
            enum Element:Grammar.TerminalClass 
            {
                typealias Terminal      = Character 
                typealias Construction  = Character 
                static 
                func parse(terminal:Character) -> Character?
                {
                    if terminal.isNewline 
                    {
                        return nil 
                    }
                    else 
                    {
                        return terminal
                    }
                }
            }
        }
        enum Element:ParsingRule
        {
            typealias Terminal = Character 
            static 
            func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) -> Markdown.Block.Element 
                where   Diagnostics:ParsingDiagnostics, 
                        Diagnostics.Source.Index == Location, Diagnostics.Source.Element == Terminal
            {
                if let level:Int = input.parse(as: Grammar.Count<Grapheme.Hashtag>?.self)
                {
                    return .block(.heading(input.parse(as: Line.Element.self, in: String.self), level: level))
                }
                else if let _:Void = input.parse(as: Indent?.self)
                {
                    var code:[String] = [input.parse(as: Line.Element.self, in: String.self)]
                    while let _:(Void, Void) = try? input.parse(as: (Grapheme.Newline, Indent).self)
                    {
                        code.append(input.parse(as: Line.Element.self, in: String.self))
                    }
                    return .block(.code(code))
                }
                else if let level:Int = input.parse(as: HorizontalRule?.self)
                {
                    return .rule(level: level)
                }
                else 
                {
                    return .line(input.parse(as: Line.Element.self, in: String.self))
                }
            }
        }
        typealias Terminal = Character 
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> [Markdown.Block] 
            where   Diagnostics:ParsingDiagnostics, 
                    Diagnostics.Source.Index == Location, Diagnostics.Source.Element == Terminal
        {
            var blocks:[Markdown.Block] = []
            var paragraph:[String]      = []
            while let next:Markdown.Block.Element = input.parse(as: Element?.self)
            {
                switch next 
                {
                case .rule(let level):
                    if !paragraph.isEmpty
                    {
                        blocks.append(.heading(paragraph.joined(separator: " "), level: level))
                        paragraph = []
                    }
                case .line(let line):
                    if line.allSatisfy(\.isWhitespace)
                    {
                        blocks.append(.paragraph(paragraph.joined(separator: " ")))
                        paragraph = []
                    }
                    else 
                    {
                        paragraph.append(line)
                    }
                case .block(let block): 
                    blocks.append(.paragraph(paragraph.joined(separator: " ")))
                    blocks.append(block)
                    paragraph = []
                }
                guard let _:Void = input.parse(as: Grapheme.Newline?.self)
                else 
                {
                    break 
                }
            }
            if !paragraph.isEmpty
            {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph = []
            }
            return blocks
        }
    }
} */

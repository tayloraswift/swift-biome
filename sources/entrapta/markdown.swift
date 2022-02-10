import Grammar 

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
        enum Element 
        {
            case rule(level:Int)
            case line(String)
            case block(Block)
        }
        
        case heading(String, level:Int)
        case paragraph(String)
        case code([String])
    }
    enum Rule<Location> 
    {
        typealias Grapheme = Grammar.Encoding<Location, Character>.Grapheme
    }
}
extension Markdown.Rule 
{
    enum Indent:Grammar.TerminalSequence
    {
        typealias Terminal = Character 
        @inlinable public static 
        var literal:String { "    " }
    }
    

    enum Block:ParsingRule 
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
}

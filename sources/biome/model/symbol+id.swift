import Grammar 

extension Biome.Symbol 
{
    enum InterfaceLanguage
    {
        case c 
        case swift 
    }
    public 
    enum ID:Hashable, CustomStringConvertible, Sendable 
    {
        @available(*, unavailable)
        var string:String { "" }
        
        @available(*, unavailable)
        init(_ string:String)
        {
            fatalError("unreachable")
        }
        
        case natural(String)
        case synthesized(String, for:String)
        
        var usr:String 
        {
            switch self 
            {
            case .natural(let string): 
                return string 
            case .synthesized(let string, for: let scope): 
                return "\(string)::SYNTHESIZED::\(scope)"
            }
        }
        
        public 
        var description:String
        {
            switch self 
            {
            case .natural(let string): 
                return Demangle[string]
            case .synthesized(let string, for: let scope): 
                return "synthesized \(Demangle[string]) for \(Demangle[scope])"
            }
        }
        
        enum Rule<Location> 
        {
            typealias ASCII = Grammar.Encoding<Location, UInt8>.ASCII
        }
    }
}

extension Biome.Symbol.ID.Rule
{
    enum Synthesized:Grammar.TerminalSequence 
    {
        typealias Terminal = UInt8
        static 
        var literal:[UInt8] 
        {
            // '::SYNTHESIZED::'
            [
                0x3a, 0x3a, 
                0x53, 0x59, 0x4e, 0x54, 0x48, 0x45, 0x53, 0x49, 0x5a, 0x45, 0x44, 
                0x3a, 0x3a
            ]
        }
    }
    enum MangledName:ParsingRule 
    {
        // all name elements can contain a number, including the first
        enum Element:Grammar.TerminalClass  
        {
            typealias Terminal      = UInt8
            typealias Construction  = Void
            static 
            func parse(terminal:UInt8) -> Void?
            {
                switch terminal 
                {
                //    '_'   'A' ... 'Z'    'a' ... 'z'    '0' ... '9',   '@'
                case 0x5f, 0x41 ... 0x5a, 0x61 ... 0x7a, 0x30 ... 0x39, 0x40:
                    return ()
                default: 
                    return nil
                }
            }
        }
        
        // Mangled Identifier ::= <Language> ':' <Mangled Identifier Head> <Mangled Identifier Next> *
        typealias Terminal      = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> String
            where   Diagnostics:ParsingDiagnostics, 
                    Diagnostics.Source.Index == Location,
                    Diagnostics.Source.Element == Terminal
        {
            let start:Location  = input.index 
            guard let _:UInt8   = input.next()
            else 
            {
                throw Biome.SymbolIdentifierError.empty 
            }
            try input.parse(as: ASCII.Colon.self)
            try input.parse(as: Element.self)
                input.parse(as: Element.self, in: Void.self)
            let end:Location    = input.index 
            return .init(decoding: input[start ..< end], as: Unicode.UTF8.self)
        }
    }
    enum USR:ParsingRule 
    {
        // USR  ::= <Mangled Name> ( '::SYNTHESIZED::' <Mangled Name> ) ?
        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> Biome.Symbol.ID
            where   Diagnostics:ParsingDiagnostics, 
                    Diagnostics.Source.Index == Location,
                    Diagnostics.Source.Element == Terminal
        {
            let first:String    = try input.parse(as: MangledName.self)
            guard let _:Void    = input.parse(as: Synthesized?.self)
            else 
            {
                return .natural(first)
            }
            let second:String   = try input.parse(as: MangledName.self)
            return .synthesized(first, for: second)
        }
    }
}

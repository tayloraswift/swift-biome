import Grammar 

extension Biome.Symbol 
{
    enum ID:Hashable, CustomStringConvertible, Sendable 
    {
        case swift([UInt8])
        case c([UInt8])
        
        var string:String 
        {
            switch self 
            {
            case .swift(let utf8): 
                return "s\(String.init(decoding: utf8, as: Unicode.UTF8.self))"
            case .c(let utf8):
                return "c\(String.init(decoding: utf8, as: Unicode.UTF8.self))"
            }
        }
        /* 
        init(_ string:String)
        {
            self.string = string 
        }
         */
        var description:String
        {
            switch self 
            {
            case .swift(let utf8):
                return Demangle[utf8]
            case .c(let utf8): 
                return "c-language symbol '\(String.init(decoding: utf8, as: Unicode.UTF8.self))'"
            }
        }
    }
}
extension Biome 
{
    enum InterfaceLanguage
    {
        case c 
        case swift 
    }
    enum USR:Hashable, Sendable 
    {
        case natural(Symbol.ID)
        case synthesized(from:Symbol.ID, for:Symbol.ID)
        
        enum Rule<Location> 
        {
            typealias ASCII = Grammar.Encoding<Location, UInt8>
        }
    }
}
extension Biome.USR.Rule:ParsingRule
{
    enum Synthesized:LiteralRule 
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
        enum Element:TerminalRule  
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
        
        // Mangled Identifier ::= <Language> ':' ? <Mangled Identifier Head> <Mangled Identifier Next> *
        typealias Terminal      = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> Biome.Symbol.ID
            where   Diagnostics:ParsingDiagnostics, 
                    Diagnostics.Source.Index == Location,
                    Diagnostics.Source.Element == Terminal
        {
            guard let language:UInt8    = input.next()
            else 
            {
                throw Graph.SymbolError.unidentified 
            }
                input.parse(as: ASCII.Colon?.self)
            let start:Location          = input.index 
            try input.parse(as: Element.self)
                input.parse(as: Element.self, in: Void.self)
            let end:Location    = input.index 
            let utf8:[UInt8]    = [UInt8].init(input[start ..< end])
            switch language 
            {
            case 0x73: // 's'
                return .swift(utf8)
            case 0x63: // 'c'
                return .c(utf8)
            case let code: 
                throw Graph.SymbolError.unsupportedLanguage(code: code)
            }
        }
    }
    
    // USR  ::= <Mangled Name> ( '::SYNTHESIZED::' <Mangled Name> ) ?
    typealias Terminal = UInt8
    static 
    func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> Biome.USR
        where   Diagnostics:ParsingDiagnostics, 
                Diagnostics.Source.Index == Location,
                Diagnostics.Source.Element == Terminal
    {
        let first:Biome.Symbol.ID   = try input.parse(as: MangledName.self)
        guard let _:Void            = input.parse(as: Synthesized?.self)
        else 
        {
            return .natural(first)
        }
        let second:Biome.Symbol.ID  = try input.parse(as: MangledName.self)
        return .synthesized(from: first, for: second)
    }
}

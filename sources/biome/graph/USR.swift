import Grammar 

enum USR:Hashable, Sendable 
{
    case natural(Symbol.ID)
    case synthesized(from:Symbol.ID, for:Symbol.ID)
}
extension USR 
{
    enum Rule<Location>
    {
        typealias Terminal = UInt8
        typealias Encoding = Grammar.Encoding<Location, Terminal>
    }
}
// it would be really nice if this were generic over ``ASCIITerminal``
extension USR.Rule:ParsingRule 
{
    private 
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
    private 
    enum Language:TerminalRule  
    {
        typealias Terminal = UInt8
        typealias Construction = Symbol.Language
        static 
        func parse(terminal:UInt8) -> Symbol.Language?
        {
            switch terminal 
            {
            case 0x73: // 's'
                return .swift
            case 0x63: // 'c'
                return .c
            default: 
                return nil
            }
        }
    }
    // all name elements can contain a number, including the first
    private 
    enum OpaqueNameElement:TerminalRule  
    {
        typealias Terminal = UInt8
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
    enum OpaqueName:ParsingRule 
    {
        typealias Terminal = UInt8
        // Mangled Identifier ::= <Language> ':' ? <Mangled Identifier Head> <Mangled Identifier Next> *
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> Symbol.ID
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            let language:Symbol.Language = try input.parse(as: Language.self)
            
            input.parse(as: Encoding.Colon?.self)
            
            let start:Location          = input.index 
            try input.parse(as: OpaqueNameElement.self)
                input.parse(as: OpaqueNameElement.self, in: Void.self)
            let end:Location    = input.index 
            
            return .init(language, input[start ..< end])
        }
    }
        
    // USR  ::= <Mangled Name> ( '::SYNTHESIZED::' <Mangled Name> ) ?
    static 
    func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> USR
        where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
    {
        let first:Symbol.ID = try input.parse(as: OpaqueName.self)
        guard let _:Void = input.parse(as: Synthesized?.self)
        else 
        {
            return .natural(first)
        }
        let second:Symbol.ID = try input.parse(as: OpaqueName.self)
        return .synthesized(from: first, for: second)
    }
}
extension USR.Rule 
{
    // example 1: 'ss8_PointerPsE11predecessorxyF'
    // 
    // 's': language is swift 
    // 's': namespace is 'Swift'
    // '8_PointerP': protocol ('P') is '_Pointer', which is 8 characters long
    // 'sE': perpetrator is 'Swift'
    
    // example 2: 's3Foo4_BarP3BazE'
    // 
    // 's': language is swift 
    // '3Foo': namespace is 'Foo'
    // '4_BarP': protocol ('P') is '_Bar', which is 4 characters long
    // '3BazE': perpetrator is 'Baz'
    // 
    // note that there would usually be more characters after this prefix.
    
    // never contains substitutions
    private
    enum MangledIdentifier:ParsingRule
    {
        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> String
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            // cannot begin with a '0', since that signifies that substitutions will occur
            let count:Int = try input.parse(as: Grammar.UnsignedNormalizedIntegerLiteral<
                Grammar.NaturalDecimalDigit<Location, Terminal, Int>, 
                Grammar.DecimalDigit       <Location, Terminal, Int>>.self)
            // FIXME: properly handle punycode
            return String.init(decoding: try input.parse(prefix: count), as: Unicode.ASCII.self)
        }
    }
    private
    enum MangledModuleName:ParsingRule
    {
        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> Module.ID
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            if let _:Void = input.parse(as: Encoding.S.Lowercase?.self)
            {
                return "Swift"
            }
            else 
            {
                return .init(try input.parse(as: MangledIdentifier.self))
            }
        }
    }
    enum MangledProtocolName:ParsingRule
    {
        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) 
            throws -> (module:Module.ID, name:String)
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            try input.parse(as: Encoding.S.Lowercase.self)
            let module:Module.ID = try input.parse(as: MangledModuleName.self)
            let name:String = try input.parse(as: MangledIdentifier.self)
            try input.parse(as: Encoding.P.Uppercase.self)
            return (module, name)
        }
    }
    enum MangledExtensionContext:ParsingRule
    {
        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> Module.ID
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            let culture:Module.ID = try input.parse(as: MangledModuleName.self)
            try input.parse(as: Encoding.E.Uppercase.self)
            return culture
        }
    }
}

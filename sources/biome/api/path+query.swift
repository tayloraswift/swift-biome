import Grammar

extension Biome.Path 
{
    enum Rule<Location> 
    {
        typealias ASCII = Grammar.Encoding<Location, UInt8>.ASCII
    }
}
extension Biome.Path.Rule 
{
    enum Query:ParsingRule 
    {
        enum Separator:Grammar.TerminalClass 
        {
            typealias Terminal      = UInt8
            typealias Construction  = Void 
            static 
            func parse(terminal:UInt8) -> Void?
            {
                switch terminal
                {
                case    0x26, // '&' 
                        0x3b: // ';' 
                    return ()
                default:
                    return nil
                }
            }
        }
        enum Item:ParsingRule 
        {
            enum CodeUnit:Grammar.TerminalClass 
            {
                typealias Terminal      = UInt8
                typealias Construction  = Void 
                static 
                func parse(terminal:UInt8) -> Void?
                {
                    switch terminal
                    {
                    case    0x26, // '&' 
                            0x3b, // ';' 
                            0x3d, // '=' 
                            0x23: // '#'
                        return nil 
                    default:
                        return ()
                    }
                }
            }
            enum CodeUnits:ParsingRule 
            {
                typealias Terminal = UInt8
                static 
                func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) -> String
                where   Diagnostics:ParsingDiagnostics, 
                        Diagnostics.Source.Index == Location, 
                        Diagnostics.Source.Element == Terminal
                {
                    let start:Location  = input.index 
                        input.parse(as: CodeUnit.self, in: Void.self)
                    let end:Location    = input.index 
                    return .init(decoding: input[start ..< end], as: Unicode.UTF8.self)
                }
                
            }
            
            typealias Terminal = UInt8
            static 
            func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> (key:String, value:String)
                where   Diagnostics:ParsingDiagnostics, 
                        Diagnostics.Source.Index == Location, 
                        Diagnostics.Source.Element == Terminal
            {
                let key:String      = try input.parse(as: CodeUnits.self)
                try input.parse(as: ASCII.Equals.self)
                let value:String    = try input.parse(as: CodeUnits.self)
                return (key, value)
            }
        }
        
        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> [(key:String, value:String)]
            where   Diagnostics:ParsingDiagnostics, 
                    Diagnostics.Source.Index == Location, 
                    Diagnostics.Source.Element == Terminal
        {
            try input.parse(as: Grammar.Join<Query.Item, Separator, [(key:String, value:String)]>.self) 
        }
    }
}

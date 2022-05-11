import Grammar

struct LexicalEndpoint 
{
    var path:[LexicalPath.Vector?]
    var query:[LexicalQuery.Parameter]?
    
    enum Rule<Location>
    {
        typealias Terminal = UInt8
        typealias Encoding = Grammar.Encoding<Location, Terminal>
    }
    private
    enum EncodedString<UnencodedByte>:ParsingRule 
    where   UnencodedByte:ParsingRule, 
            UnencodedByte.Terminal == UInt8,
            UnencodedByte.Construction == Void
    {
        typealias Location = UnencodedByte.Location 
        typealias Terminal = UnencodedByte.Terminal
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> (string:String, unencoded:Bool)
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            let start:Location      = input.index 
            input.parse(as: UnencodedByte.self, in: Void.self)
            let end:Location        = input.index 
            var string:String       = .init(decoding: input[start ..< end], as: Unicode.UTF8.self)
            
            while let utf8:[UInt8]  = input.parse(as: Grammar.Reduce<Rule<Location>.EncodedByte, [UInt8]>?.self)
            {
                string             += .init(decoding: utf8,                 as: Unicode.UTF8.self)
                let start:Location  = input.index 
                input.parse(as: UnencodedByte.self, in: Void.self)
                let end:Location    = input.index 
                string             += .init(decoding: input[start ..< end], as: Unicode.UTF8.self)
            }
            return (string, end == input.index)
        }
    } 
}
extension LexicalEndpoint.Rule:ParsingRule 
{
    fileprivate 
    enum EncodedByte:ParsingRule
    {
        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> UInt8
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            try input.parse(as: Grammar.Encoding<Location, Terminal>.Percent.self)
            let high:UInt8  = try input.parse(as: Grammar.HexDigit<Location, Terminal, UInt8>.self)
            let low:UInt8   = try input.parse(as: Grammar.HexDigit<Location, Terminal, UInt8>.self)
            return high << 4 | low
        }
    } 

    // `Vector` and `Query` can only be defined for UInt8 because we are decoding UTF-8 to a String    
    private
    enum Vector:ParsingRule 
    {
        enum Separator:TerminalRule
        {
            typealias Terminal = UInt8
            typealias Construction = Void
            static 
            func parse(terminal:Terminal) -> Void? 
            {
                switch terminal 
                {
                //    '/'   '\'
                case 0x2f, 0x5c: return ()
                default: return nil
                }
            }
        }
        /// Matches a UTF-8 code unit that is allowed to appear inline in URL path component. 
        enum UnencodedByte:TerminalRule
        {
            typealias Terminal = UInt8
            typealias Construction = Void 
            static 
            func parse(terminal:UInt8) -> Void? 
            {
                switch terminal 
                {
                //    '%',  '/',  '\',  '?',  '#'
                case 0x25, 0x2f, 0x5c, 0x3f, 0x23:
                    return nil
                default:
                    return ()
                }
            }
        } 
        
        enum Component:ParsingRule 
        {
            typealias Terminal = UInt8
            static 
            func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> LexicalPath.Vector?
                where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
            {
                let (string, unencoded):(String, Bool) = try input.parse(as: LexicalEndpoint.EncodedString<UnencodedByte>.self)
                guard unencoded
                else 
                {
                    // component contained at least one percent-encoded character
                    return string.isEmpty ? nil : .push(string)
                }
                switch string 
                {
                case "", ".":   return  nil
                case    "..":   return .pop
                case let next:  return .push(next)
                }
            }
        }

        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> LexicalPath.Vector?
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            try input.parse(as: Separator.self)
            return try input.parse(as: Component.self)
        }
    }
    private 
    enum Parameter:ParsingRule 
    {
        enum Separator:TerminalRule 
        {
            typealias Terminal = UInt8
            typealias Construction = Void 
            static 
            func parse(terminal:Terminal) -> Void?
            {
                switch terminal
                {
                //    '&'   ';' 
                case 0x26, 0x3b: 
                    return ()
                default:
                    return nil
                }
            }
        }
        enum UnencodedByte:TerminalRule 
        {
            typealias Terminal = UInt8
            typealias Construction = Void 
            static 
            func parse(terminal:Terminal) -> Void?
            {
                switch terminal
                {
                //    '&'   ';'   '='   '#'
                case 0x26, 0x3b, 0x3d, 0x23:
                    return nil 
                default:
                    return ()
                }
            }
        }
        
        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> LexicalQuery.Parameter
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            let (key, _):(String, Bool) = try input.parse(as: LexicalEndpoint.EncodedString<UnencodedByte>.self)
            try input.parse(as: Encoding.Equals.self)
            let (value, _):(String, Bool) = try input.parse(as: LexicalEndpoint.EncodedString<UnencodedByte>.self)
            return (key, value)
        }
    }
    
    // always contains at least one vector, and can be absolute or relative 
    private
    enum VectorList:ParsingRule 
    {
        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) 
            throws -> (absolute:Bool, vectors:[LexicalPath.Vector?])
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            let absolute:Bool 
            var vectors:[LexicalPath.Vector?] 
            if let first:LexicalPath.Vector? = input.parse(as: Vector?.self)
            {
                absolute = true
                vectors = [first]
            }
            else 
            {
                absolute = false 
                vectors = [try input.parse(as: Vector.Component.self)]
            }
            while let next:LexicalPath.Vector? = input.parse(as: Vector?.self)
            {
                vectors.append(next)
            }
            return (absolute, vectors)
        }
    }
    // always begins with '?', but may be empty 
    private
    enum ParameterList:ParsingRule 
    {
        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) 
            throws -> [LexicalQuery.Parameter]
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            try input.parse(as: Encoding.Question.self)
            return input.parse(as: Grammar.Join<Parameter, Parameter.Separator, [LexicalQuery.Parameter]>?.self) ?? []
        }
    }
    
    enum LinkExpression:ParsingRule 
    {
        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) 
            throws -> (absolute:Bool, vectors:[LexicalPath.Vector?], parameters:[LexicalQuery.Parameter])
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            let path:(absolute:Bool, vectors:[LexicalPath.Vector?]) = try input.parse(as: VectorList.self)
            let parameters:[LexicalQuery.Parameter] = input.parse(as: ParameterList?.self) ?? []
            return (path.absolute, path.vectors, parameters)
        }
    }

    static 
    func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) -> LexicalEndpoint
        where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
    {
        //  i. lexical segmentation and percent-decoding 
        //
        //  '//foo/bar/.\bax.qux/..//baz./.Foo/%2E%2E//' becomes 
        // ['', 'foo', 'bar', < None >, 'bax.qux', < Self >, '', 'baz.bar', '.Foo', '..', '', '']
        // 
        //  the first slash '/' does not generate an empty component.
        //  this is the uri we percieve as the uri entered by the user, even 
        //  if their slash ('/' vs '\') or percent-encoding scheme is different.
        let path:[LexicalPath.Vector?] = input.parse(as: Vector.self, in: [LexicalPath.Vector?].self)
        let query:[LexicalQuery.Parameter]? = input.parse(as: ParameterList?.self)
        return .init(path: path, query: query)
    }
}

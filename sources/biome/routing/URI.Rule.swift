import Grammar

extension URI 
{
    public 
    enum Rule<Location>
    {
        public 
        typealias Terminal = UInt8
        public 
        typealias Encoding = Grammar.Encoding<Location, Terminal>
    }
    public
    enum EncodedString<UnencodedByte>:ParsingRule 
    where   UnencodedByte:ParsingRule, 
            UnencodedByte.Terminal == UInt8,
            UnencodedByte.Construction == Void
    {
        public 
        typealias Location = UnencodedByte.Location 
        public 
        typealias Terminal = UnencodedByte.Terminal
        
        @inlinable public static 
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
extension URI.Rule:ParsingRule 
{
    public 
    enum EncodedByte:ParsingRule
    {
        public
        typealias Terminal = UInt8
        
        @inlinable public static 
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
    public
    enum Vector:ParsingRule 
    {
        public
        enum Separator:TerminalRule
        {
            public
            typealias Terminal = UInt8
            public
            typealias Construction = Void
            
            @inlinable public static 
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
        public
        enum UnencodedByte:TerminalRule
        {
            public
            typealias Terminal = UInt8
            public
            typealias Construction = Void 
            
            @inlinable public static 
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
        public
        enum Component:ParsingRule 
        {
            public
            typealias Terminal = UInt8
            
            @inlinable public static 
            func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> URI.Vector?
                where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
            {
                let (string, unencoded):(String, Bool) = try input.parse(as: URI.EncodedString<UnencodedByte>.self)
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
        
        public
        typealias Terminal = UInt8
        
        @inlinable public static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> URI.Vector?
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            try input.parse(as: Separator.self)
            return try input.parse(as: Component.self)
        }
    }
    public 
    enum Parameter:ParsingRule 
    {
        public
        enum Separator:TerminalRule 
        {
            public
            typealias Terminal = UInt8
            public
            typealias Construction = Void 
            
            @inlinable public static 
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
        public
        enum UnencodedByte:TerminalRule 
        {
            public 
            typealias Terminal = UInt8
            public 
            typealias Construction = Void 
            
            @inlinable public static 
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
        
        public
        typealias Terminal = UInt8
        
        @inlinable public static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> URI.Parameter
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            let (key, _):(String, Bool) = try input.parse(as: URI.EncodedString<UnencodedByte>.self)
            try input.parse(as: Encoding.Equals.self)
            let (value, _):(String, Bool) = try input.parse(as: URI.EncodedString<UnencodedByte>.self)
            return (key, value)
        }
    }

    // always begins with '?', but may be empty 
    public
    enum ParameterList:ParsingRule 
    {
        public 
        typealias Terminal = UInt8
        
        @inlinable public static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) 
            throws -> [URI.Parameter]
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            try input.parse(as: Encoding.Question.self)
            return input.parse(as: Grammar.Join<Parameter, Parameter.Separator, [URI.Parameter]>?.self) ?? []
        }
    }
    
    // always contains at least one vector ('/' -> [.push("")])
    public 
    enum Absolute:ParsingRule 
    {
        public
        typealias Terminal = UInt8

        @inlinable public static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> URI
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
            let path:[URI.Vector?] = try input.parse(as: Grammar.Reduce<Vector, [URI.Vector?]>.self)
            let query:[URI.Parameter]? = input.parse(as: ParameterList?.self)
            return .init(path: path, query: query)
        }
    }
    // always contains at least one vector, but it may be empty
    public 
    enum Relative:ParsingRule 
    {
        public
        typealias Terminal = UInt8
        
        @inlinable public static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> URI
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            var path:[URI.Vector?] = [try input.parse(as: Vector.Component.self)]
            while let next:URI.Vector? = input.parse(as: Vector?.self)
            {
                path.append(next)
            }
            let query:[URI.Parameter]? = input.parse(as: ParameterList?.self)
            return .init(path: path, query: query)
        }
    }
    
    @inlinable public static 
    func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) 
        throws -> (absolute:Bool, uri:URI)
        where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
    {
        if let uri:URI = input.parse(as: Absolute?.self)
        {
            return (true, uri) 
        }
        else 
        {
            return (false, try input.parse(as: Relative.self))
        }
    }
}

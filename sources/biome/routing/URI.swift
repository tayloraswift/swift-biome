import Grammar

extension Collection where Element == URI.Vector?
{
    var normalized:(components:[String], fold:Int)
    {
        // ii. lexical normalization 
        //
        // ['', 'foo', 'bar', < nil >, 'bax.qux', < Self >, '', 'baz.bar', '.Foo', '..', '', ''] becomes 
        // [    'foo', 'bar',                                   'baz.bar', '.Foo', '..']
        //                                                      ^~~~~~~~~~~~~~~~~~~~~~~
        //                                                      (visible = 3)
        //  if `Self` components would erase past the beginning of the components list, 
        //  the extra `Self` components are ignored.
        //  redirects generated from this step are PERMANENT. 
        //  paths containing `nil` and empty components always generate redirects.
        //  however, the presence and location of an empty component can be meaningful 
        //  in a symbollink.    
        var components:[String] = []
            components.reserveCapacity(self.underestimatedCount)
        var fold:Int = components.endIndex
        for vector:URI.Vector? in self
        {
            switch vector 
            {
            case .pop?:
                let _:String? = components.popLast()
                fallthrough
            case nil: 
                fold = components.endIndex
            case .push(let component): 
                components.append(component)
            }
        }
        return (components, fold)
    }
}

public
struct URI 
{
    enum Vector:Hashable, Sendable
    {
        /// '..'
        case pop 
        /// A regular path component. This can be '.' or '..' if at least one 
        /// of the dots was percent-encoded.
        case push(String)
    }
    typealias Parameter = (key:String, value:String)
    
    var path:[Vector?]
    var query:[Parameter]?
    
    var description:String 
    {
        var string:String = ""
        for vector:Vector? in self.path
        {
            switch vector
            {
            case  nil: 
                string += "/."
            case .pop?: 
                string += "/.."
            case .push(let component)?: 
                string += "/\(Self.encode(utf8: component.utf8))"
            }
        }
        guard let parameters:[Parameter] = self.query 
        else 
        {
            return string
        }
        // don’t bother percent-encoding the query parameters
        string.append("?")
        string += parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        return string
    }
    
    static 
    func ~= (lhs:Self, rhs:Self) -> Bool 
    {
        guard lhs.path == rhs.path 
        else 
        {
            return false 
        }
        switch (lhs.query, rhs.query)
        {
        case (_?, nil), (nil, _?): 
            return false
        case (nil, nil):
            return true 
        case (let lhs?, let rhs?):
            guard lhs.count == rhs.count 
            else 
            {
                return false 
            }
            var unmatched:[String: String] = .init(minimumCapacity: lhs.count)
            for (key, value):(String, String) in lhs 
            {
                guard case nil = unmatched.updateValue(value, forKey: key)
                else
                {
                    return false
                }
            }
            for (key, value):(String, String) in rhs
            {
                guard case value? = unmatched.removeValue(forKey: key)
                else
                {
                    return false
                }
            }
            return true
        }
    }
    
    init(path:[Vector?], query:[Parameter]?)
    {
        self.path = path 
        self.query = query
    }
    init<S>(absolute string:S) throws where S:StringProtocol
    {
        self = try Grammar.parse(string.utf8, as: URI.Rule<String.Index>.Absolute.self)
    }
    init<S>(relative string:S) throws where S:StringProtocol
    {
        self = try Grammar.parse(string.utf8, as: URI.Rule<String.Index>.Relative.self)
    }
    
    init(prefix:String, 
        path:[String], 
        orientation:Symbol.Link.Orientation = .straight)
    {
        self.path = []
        if case .gay = orientation, path.count >= 2
        {
            self.path.reserveCapacity(path.count)
            self.path.append(.push(prefix))
            for component:String in path.dropLast(2)
            {
                self.path.append(.push(component))
            }
            let penultimate:String = path[path.endIndex - 2]
            let    ultimate:String = path[path.endIndex - 1]
            self.path.append(.push("\(penultimate).\(ultimate)"))
        }
        else 
        {
            self.path.reserveCapacity(path.count + 1)
            self.path.append(.push(prefix))
            for component:String in path
            {
                self.path.append(.push(component))
            }
        }
        self.query = nil
    }
    init(prefix:String, 
        path:[String], 
        query:Symbol.Link.Query = .init(), 
        orientation:Symbol.Link.Orientation = .straight)
    {
        self.init(prefix: prefix, path: path, orientation: orientation)
        self.insert(query)
    }
    private mutating 
    func insert(_ query:Symbol.Link.Query)
    {
        if let base:Symbol.ID = query.base
        {
            self.insert((Symbol.Link.Query.base, base.string))
        }
        if let host:Symbol.ID = query.host
        {
            self.insert((Symbol.Link.Query.host, host.string))
        }
        switch query.lens
        {
        case nil: 
            break 
        case (let culture, nil)?:
            self.insert((Symbol.Link.Query.lens,    culture.string))
        case (let culture, let version?)?:
            self.insert((Symbol.Link.Query.lens, "\(culture.string)/\(version.description)"))
        }
    }
    private mutating 
    func insert(_ parameter:Parameter) 
    {
        switch self.query 
        {
        case nil:
            self.query = [parameter]
        case var parameters?:
            self.query = nil 
            parameters.append(parameter)
            self.query = parameters
        }
    }
    
    private static 
    func encode<UTF8>(utf8 bytes:UTF8) -> String
        where UTF8:Sequence, UTF8.Element == UInt8
    {
        var utf8:[UInt8] = []
            utf8.reserveCapacity(bytes.underestimatedCount)
        for byte:UInt8 in bytes
        {
            if let byte:UInt8 = Self.filter(byte: byte)
            {
                utf8.append(byte)
            }
            else 
            {
                // percent-encode
                utf8.append(0x25) // '%'
                utf8.append(Self.hex(uppercasing: byte >> 4))
                utf8.append(Self.hex(uppercasing: byte & 0x0f))
            }
        }
        return .init(unsafeUninitializedCapacity: utf8.count) 
        { 
            $0.initialize(from: utf8).1 - $0.startIndex
        }
    }
    private static 
    func filter(byte:UInt8) -> UInt8?
    {
        switch byte 
        {
        case    0x30 ... 0x39,  // [0-9]
                0x41 ... 0x5a,  // [A-Z]
                0x61 ... 0x7a,  // [a-z]
                0x2d,           // '-'
                0x2e,           // '.'
                // not technically a URL character, but browsers won’t render '%3A' 
                // in the URL bar, and ':' is so common in Swift it is not worth 
                // percent-encoding. 
                // the ':' character also appears in legacy USRs.
                0x3a,           // ':' 
                0x5f,           // '_'
                0x7e:           // '~'
            return byte 
        default: 
            return nil 
        }
    }
    private static 
    func hex(uppercasing value:UInt8) -> UInt8
    {
        (value < 10 ? 0x30 : 0x37) + value 
    }
    
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
extension URI.Rule:ParsingRule 
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

        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> URI.Vector?
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
    private
    enum ParameterList:ParsingRule 
    {
        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) 
            throws -> [URI.Parameter]
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any
        {
            try input.parse(as: Encoding.Question.self)
            return input.parse(as: Grammar.Join<Parameter, Parameter.Separator, [URI.Parameter]>?.self) ?? []
        }
    }
    
    // always contains at least one vector ('/' -> [.push("")])
    enum Absolute:ParsingRule 
    {
        typealias Terminal = UInt8

        static 
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
    enum Relative:ParsingRule 
    {
        typealias Terminal = UInt8
        static 
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
    
    static 
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

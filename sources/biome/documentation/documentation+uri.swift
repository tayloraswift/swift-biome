import Grammar

extension Documentation
{    
    func normalize(uri:String) -> (uri:URI, changed:Bool)
    {
        let path:Substring, 
            query:Substring?
        switch (question: uri.firstIndex(of: "?"), hash: uri.firstIndex(of: "#"))
        {
        case (question: let question?, hash: let hash?):
            guard question < hash 
            else 
            {
                fallthrough
            }
            path    = uri[..<question]
            query   = uri[question ..< hash].dropFirst()
        case (question: nil          , hash: let hash?):
            path    = uri[..<hash]
            query   = nil
        case (question: let question?, hash: nil):
            path    = uri[..<question]
            query   = uri[question...].dropFirst()
        case (question: nil          , hash: nil):
            path    = uri[...]
            query   = nil
        }
        return self.normalize(path: path, query: query)
    }
    private 
    func normalize(path:Substring, query:Substring?) -> (uri:URI, changed:Bool)
    {
        var changed:Bool        = false 
        let uri:URI  = .init(
            path:  self.normalize(path:  path,  changed: &changed),
            query: self.normalize(query: query, changed: &changed))
        return (uri, changed)
    }
    private 
    func normalize(path:Substring, changed:inout Bool) -> URI.Path
    {
        var prefix:String.Iterator  = self.routing.prefix.makeIterator()
        var start:String.Index      = path.endIndex
        for index:String.Index in path.indices
        {
            guard let expected:Character = prefix.next() 
            else 
            {
                start = index 
                break 
            }
            guard path[index] == expected 
            else 
            {
                // bogus path prefix. this usually happens when the surrounding 
                // server performs some kind of path normalization that doesn’t 
                // agree with the `prefix` it initialized these docs with.
                changed = true 
                return .init(stem: [], leaf: [])
            }
        }
        var path:Substring.UTF8View = path[start...].utf8
        switch path.first 
        {
        case 0x2f?: 
            break 
        case _?: // does not start with a '/'
            changed = true 
            fallthrough 
        case nil: 
            // is completely empty (except for the prefix)
            return .init(stem: [], leaf: [])
        }
        
        path = path.dropFirst()
        
        let dot:String.Index            = path.firstIndex(of: 0x2e) ?? path.endIndex
        var stem:[Substring.UTF8View]   = path[..<dot].split(separator: 0x2f, 
            omittingEmptySubsequences: false)

        let leaf:Substring.UTF8View
        switch stem.last?.isEmpty
        {
        case nil, true?: 
            //  if the stem ends with a slash, it will end in an empty substring. 
            //  in this case, preserve the leading dot, and consider it part of the 
            //  leaf. this allows us to redirect the range operator URI 
            //
            //      '/reference/swift/comparable/...(_:_:)'
            //
            //  to its canonical form:
            //
            //      '/reference/swift/comparable....(_:_:)'
            // 
            //  we don’t need any special logic for top-level operators that begin 
            //  with a dot, because we have not parsed the root or trunk segments.
            // 
            //  leaves are allowed at the top level, banning them would require 
            //  us to recursively check `stem.last`, since there could be multiple 
            //  consecutive slashes.
            leaf = path[dot...]
        case false?: 
            leaf = path[dot...].dropFirst()
        }
        
        let count:Int = stem.count
            stem.removeAll(where: \.isEmpty)
        if  stem.count != count 
        {
            // path contained consecutive slashes
            changed = true 
        }
        
        return .init(
            stem: URI.normalize(path:      stem, changed: &changed), 
            leaf: URI.normalize(component: leaf, changed: &changed))
    }
    private  
    func normalize(query:Substring?, changed:inout Bool) -> URI.Query?
    {
        guard let query:Substring = query
        else 
        {
            return nil
        }
        // accept empty query, as this models the lone '?' suffix, which is distinct 
        // from `nil` query
        guard let query:[(key:[UInt8], value:[UInt8])] = 
            try? Grammar.parse(query.utf8, as: URI.Rule<String.Index>.Query.self)
        else 
        {
            changed = true 
            return nil
        }
        
        changed = changed || query.isEmpty
        
        var witness:Int?    = nil  
        var victim:Int?     = nil
        
        for (key, value):([UInt8], [UInt8]) in query 
        {
            let id:(witness:Biome.Symbol.ID?, victim:Biome.Symbol.ID?)
            parameter:
            switch String.init(decoding: key, as: Unicode.UTF8.self)
            {
            case "self": 
                if let victim:Biome.Symbol.ID = try? Grammar.parse(value, as: Biome.USR.Rule<Array<UInt8>.Index>.MangledName.self)
                {
                    // if the mangled name contained a colon ('SymbolGraphGen style')
                    // get rid of it 
                    changed = changed || value.contains(0x3a) 
                    id      = (nil, victim)
                }
                else 
                {
                    changed = true
                    id      = (nil, nil)
                }
            
            case "overload": 
                switch try? Grammar.parse(value, as: Biome.USR.Rule<Array<UInt8>.Index>.self) 
                {
                case nil: 
                    changed = true 
                    continue  
                case .natural(let natural)?:
                    
                    changed = changed || value.contains(0x3a) 
                    id      = (natural, nil)
                
                case .synthesized(from: let witness, for: let victim)?:
                    // this is supported for backwards-compatibility, 
                    // but the `::SYNTHESIZED::` infix is deprecated, so issue 
                    // a redirect 
                    changed = true 
                    id      = (witness, victim)
                }

            default: 
                changed = true 
                continue  
            }
            
            if  let index:Int = id.witness.flatMap(self.biome.symbols.index(of:))
            {
                if case nil = witness
                {
                    witness = index 
                }
                else 
                {
                    changed = true 
                }
            }
            if  let index:Int = id.victim.flatMap(self.biome.symbols.index(of:))
            {
                if case nil = victim
                {
                    victim  = index 
                }
                else
                {
                    changed = true 
                }
            }
        }
        //  victim id without witness id is useless 
        return witness.map { .init(witness: $0, victim: victim) }
    }
}
extension Documentation.URI
{
    static 
    func encode<Component>(component:Component) -> [UInt8]
        where Component:Sequence, Component.Element == UInt8
    {
        var utf8:[UInt8] = []
            utf8.reserveCapacity(component.underestimatedCount)
        for byte:UInt8 in component
        {
            if let unencoded:UInt8 = Self.normalize(byte: byte, mask: 0x20)
            {
                utf8.append(unencoded)
            }
            else 
            {
                // percent-encode
                utf8.append(0x25) // '%'
                utf8.append(Self.hex(uppercasing: byte >> 4))
                utf8.append(Self.hex(uppercasing: byte & 0x0f))
            }
        }
        return utf8
    }
    
    static 
    func normalize<Path>(path:Path, changed:inout Bool) -> [[UInt8]]
        where Path:Sequence, Path.Element:Sequence, Path.Element.Element == UInt8
    {
        path.map 
        {
            Self.normalize(component: $0, changed: &changed)
        }
    }
    static 
    func normalize<Component>(component:Component, changed:inout Bool) -> [UInt8]
        where Component:Sequence, Component.Element == UInt8
    {
        Self.decode(component: component, changed: &changed, mask: 0x20)
    }
    // this is not the entire key=value pair, as it does not accept '='
    private static 
    func normalize<Query>(query:Query) -> [UInt8]
        where Query:Sequence, Query.Element == UInt8
    {
        var never:Bool = true
        return Self.decode(component: query, changed: &never, mask: 0x00)
    }
    
    private static 
    func decode<Component>(component:Component, changed:inout Bool, mask:UInt8) -> [UInt8]
        where Component:Sequence, Component.Element == UInt8
    {
        var iterator:Component.Iterator = component.makeIterator()
        var utf8:[UInt8]                = []
            utf8.reserveCapacity(component.underestimatedCount)
        looping:
        while let head:UInt8 = iterator.next() 
        {
            let byte:UInt8 
            decoding:
            if  head == 0x25 // '%'
            {
                guard let first:UInt8   = iterator.next()
                else 
                {
                    utf8.append(head)
                    break looping
                }
                guard let high:UInt8    = Grammar.Digit<Never, UInt8, UInt8>.ASCII.Hex.Anycase.parse(terminal: first)
                else 
                {
                    // not a hex digit 
                    utf8.append(head)
                    utf8.append(first)
                    continue looping
                }
                guard let second:UInt8  = iterator.next()
                else 
                {
                    // only one hex digit. interpret it as the *low* nibble 
                    // e.g. %A -> %0A
                    byte = high 
                    break decoding 
                }
                guard let low:UInt8     = Grammar.Digit<Never, UInt8, UInt8>.ASCII.Hex.Anycase.parse(terminal: second)
                else 
                {
                    // not a hex digit
                    utf8.append(head)
                    utf8.append(first)
                    utf8.append(second)
                    continue looping 
                }
                
                byte = high << 4 | low
            }
            else 
            {
                byte = head 
            }
            if let unencoded:UInt8 = Self.normalize(byte: byte, mask: mask)
            {
                // this is a byte that should not be percent-encoded. 
                // we only ever mark the string as `changed` if `mask` is non-zero; 
                // bytes that are excessively percent-encoded will not cause a redirect
                changed = changed || unencoded != byte
                utf8.append(unencoded)
            }
            else 
            {
                // this is a byte that should be percent-encoded. 
                // we don’t force a redirect if the peer did not adequately percent- 
                // encode the byte.
                utf8.append(0x25) // '%'
                utf8.append(Self.hex(uppercasing: byte >> 4))
                utf8.append(Self.hex(uppercasing: byte & 0x0f))
            }
        }
        return utf8
    }
    private static 
    func hex(uppercasing value:UInt8) -> UInt8
    {
        (value < 10 ? 0x30 : 0x37) + value 
    }
    private static 
    func normalize(byte:UInt8, mask:UInt8) -> UInt8?
    {
        switch byte 
        {
        case    0x41 ... 0x5a:  // [A-Z] -> [a-z]
            return byte | mask
        case    0x30 ... 0x39,  // [0-9]
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
    
    enum Rule<Location> 
    {
        typealias ASCII = Grammar.Encoding<Location, UInt8>.ASCII
    }
}
extension Documentation.URI.Rule 
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
                func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) -> [UInt8]
                where   Diagnostics:ParsingDiagnostics, 
                        Diagnostics.Source.Index == Location, 
                        Diagnostics.Source.Element == Terminal
                {
                    let start:Location  = input.index 
                        input.parse(as: CodeUnit.self, in: Void.self)
                    let end:Location    = input.index 
                    return Documentation.URI.normalize(query: input[start ..< end])
                }
            }
            
            typealias Terminal = UInt8
            static 
            func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> (key:[UInt8], value:[UInt8])
                where   Diagnostics:ParsingDiagnostics, 
                        Diagnostics.Source.Index == Location, 
                        Diagnostics.Source.Element == Terminal
            {
                let key:[UInt8]     = try input.parse(as: CodeUnits.self)
                try input.parse(as: ASCII.Equals.self)
                let value:[UInt8]   = try input.parse(as: CodeUnits.self)
                return (key, value)
            }
        }
        
        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> [(key:[UInt8], value:[UInt8])]
            where   Diagnostics:ParsingDiagnostics, 
                    Diagnostics.Source.Index == Location, 
                    Diagnostics.Source.Element == Terminal
        {
            try input.parse(as: Grammar.Join<Query.Item, Separator, [(key:[UInt8], value:[UInt8])]>.self) 
        }
    }
}

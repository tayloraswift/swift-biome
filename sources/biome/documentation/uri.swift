import Grammar

extension Documentation 
{
    public 
    struct URI:Equatable, CustomStringConvertible, Sendable 
    {
        //  4 ways to access docs:
        //  1.  ( path + ) witness id + victim id
        //      '/garbage?overload=s:s4SIMDPsSF6ScalarRpzrlE2meoiyyxz_xtFZ&self=s:s5SIMD2V'
        // 
        //      uniquely identifies a symbol. path is for ui purposes only
        //      and is completely ignored.
        // 
        //      redirects:
        //      -   when the uri is not canonical. this uri is almost never 
        //          canonical because the victim id is only necessary if the victim 
        //          collides with another symbol under case-folding.
        //  2.  path + witness id
        //      '/simd2/*=(_:_:)?overload=s:s4SIMDPsSF6ScalarRpzrlE2meoiyyxz_xtFZ'
        // 
        //      only available when unambiguous. path *may* uniquely define a victim, 
        //      or the witness’s own scope. 
        // 
        //      path can be empty if the witness is mythical.
        // 
        //      never redirects because the lookup will fail in the first place 
        //      if the uri is not canonical. 
        // 
        //  3.  path only
        //      '/simd2/*=(_:_:)?overload=garbage'
        // 
        //      only available when unambiguous.
        // 
        //      redirects: 
        //      -   when falling through due to a garbage witness or victim id
        //      -   up, when the uri is not canonical. this can happen when the perpetrator 
        //          (a module) is not a citizen of the victim’s package. 
        //
        //          for example, the perpetrator can be a module in package A, 
        //          extending a victim in package B to conform to a protocol with 
        //          an extension (the witness) in package C. (note that the protocol 
        //          could be defined in a *fourth* package D, but that is not 
        //          important here.) 
        //
        //          it does not matter what package the witness is from, although 
        //          it is usually from the same package as the perpetrator. 
        //          note that the perpetrator itself has no documentation footprint, 
        //          it is only observable from the witnesses it traffics into 
        //          various victim packages. however, allowing the foreign winesses 
        //          to live unqualified in the victim package’s namespace could 
        //          potentially break the victim package’s internal links, which 
        //          would not be politically wise. 
        //
        //          note that we redirect to a *witness id*, because the victim 
        //          is already encoded in the path. 
        // 
        //  4.  witness id only
        //      '/garbage?overload=s:s4SIMDPsSF6ScalarRpzrlE2meoiyyxz_xtFZ'
        // 
        //      only available when unambiguous. (witness cannot be inherited.)
        // 
        //      always redirects. UNIMPLEMENTED.
        //
        enum Resolved:Hashable, Sendable
        {
            case article(Int, stem:UInt, leaf:UInt)
            //  '/'
            // case root 
            //  '/' 'swift-standard-library'
            //  '/' 'swift-standard-library' '/search' ( '.' 'json' )
            case package(Int, stem:UInt, leaf:UInt)
            //  '/' 'swift'
            //  '/' 'swift-nio/niocore'
            //  '/' 'swift-nio/niocore' '/foo/bar' ( '.' 'baz(_:)' ) ( '?overload=' 's:xxx' )
            case namespaced(Int, stem:UInt, leaf:UInt, overload:Int?)
            //  '?overload=' 's:xxx' '&self=' 's:yyy'
            //  note: victim can be `nil` if the symbol is mythical, and is not synthesized
            case resolution(witness:Int, victim:Int?)
        }
        enum Overloading
        {
            case witness   
            case crime
        }
        /* enum Redirect
        {
            case temporary 
            case permanent
        } */
        public 
        enum Base:Hashable, Sendable
        {
            case biome 
            case learn 
            
            var offset:KeyPath<RoutingTable, String> 
            {
                switch self 
                {
                case .biome:    return \.base.biome
                case .learn:    return \.base.learn
                }
            }
        }
        struct Path:Hashable, CustomStringConvertible, Sendable 
        {
            var stem:[[UInt8]], 
                leaf:[UInt8]
            
            init(root:[UInt8], trunk:[UInt8], stem:[[UInt8]], leaf:[UInt8])
            {
                switch (root.isEmpty, trunk.isEmpty)
                {
                case (true,   true):    self.init(stem:                 stem, leaf: leaf)
                case (false,  true):    self.init(stem: [root       ] + stem, leaf: leaf)
                case (false, false):    self.init(stem: [root, trunk] + stem, leaf: leaf)
                case (true,  false):    self.init(stem: [      trunk] + stem, leaf: leaf)
                }
            }
            init(root:[UInt8], stem:[[UInt8]], leaf:[UInt8])
            {
                switch root.isEmpty 
                {
                case true:              self.init(stem:          stem, leaf: leaf)
                case false:             self.init(stem: [root] + stem, leaf: leaf)
                }
            }
            init(stem:[[UInt8]], leaf:[UInt8])
            {
                self.stem = stem 
                self.leaf = leaf 
            }
            
            /* static 
            func normalize(joined path:Substring.UTF8View) -> Self
            {
                var whatever:Bool = true 
                return .normalize(joined: path, changed: &whatever)
            } */
            // does *not* expect a leading slash
            static 
            func normalize(joined path:Substring.UTF8View, changed:inout Bool) -> Self
            {
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
                
                return self.init(
                    stem: URI.normalize(path:      stem, changed: &changed), 
                    leaf: URI.normalize(component: leaf, changed: &changed))
            }
            
            var description:String 
            {
                """
                \(self.stem.map 
                { 
                    "/\(String.init(decoding: $0, as: Unicode.UTF8.self))" 
                }.joined())\
                \(self.leaf.isEmpty ? "" : ".\(String.init(decoding: self.leaf, as: Unicode.UTF8.self))")
                """
            }
        }
        struct Query:Hashable, CustomStringConvertible, Sendable 
        {
            var witness:Int, 
                victim:Int?
            
            var description:String 
            {
                "?overload=[\(self.witness)]\(self.victim.map { "&self=[\($0)]" } ?? "")"
            }
        }
        
        var base:Base
        var path:Path
        var query:Query?
        
        init(base:Base, path:Path, query:Query? = nil)
        {
            self.base = base
            self.path = path 
            self.query = query 
        }
        
        public 
        var description:String 
        {
            "\(self.base):\(self.path)\(self.query?.description ?? "")"
        }
        
        static 
        func concatenate<Stem>(normalized stem:Stem) -> [UInt8]
            where Stem:Collection, Stem.Element:Sequence, Stem.Element.Element == UInt8
        {
            var utf8:[UInt8] = []
                utf8.reserveCapacity(stem.reduce(0) { $0 + $1.underestimatedCount + 1 })
            for component:Stem.Element in stem 
            {
                utf8.append(0x2f)
                utf8.append(contentsOf: component)
            }
            return utf8
        }
    }
    
    func uri(article:Int) -> URI  
    {
        let namespace:Int = self.articles[article].trunk
        return .init(
            base: .learn,
            path: .init(
                root:  self.biome.root(namespace: namespace), 
                trunk: self.biome.modules[namespace].id.trunk, 
                stem:  self.articles[article].stem, 
                leaf:  []))
    }
    func uri(packageSearchIndex package:Int) -> URI  
    {
        self.biome.uri(packageSearchIndex: package)
    }
    func uri(package:Int) -> URI  
    {
        self.biome.uri(package: package)
    }
    func uri(module:Int) -> URI 
    {
        self.biome.uri(module: module)
    }
    func uri(witness:Int, victim:Int?) -> URI   
    {
        self.biome.uri(witness: witness, victim: victim, routing: self.routing)
    }
    
    func print(uri:URI) -> String 
    {
        self.biome.format(uri: uri, routing: self.routing)
    }
}
extension Biome 
{
    // uris 
    func uri(packageSearchIndex package:Int) -> Documentation.URI  
    {
        return .init(
            base: .biome,
            path: .init(
                root: self.packages[package].id.root, 
                stem: self.stem(packageSearchIndex: package), 
                leaf: self.leaf(packageSearchIndex: package)))
    }
    func uri(package:Int) -> Documentation.URI  
    {
        .init(
            base: .biome,
            path: .init(
                root: self.packages[package].id.root, 
                stem: [], 
                leaf: []))
    }
    func uri(module:Int) -> Documentation.URI 
    {
        .init(
            base: .biome,
            path: .init(
                root:  self.root(namespace: module), 
                trunk: self.modules[module].id.trunk, 
                stem: [], 
                leaf: []))
    }
    func uri(witness:Int, victim:Int?, routing:Documentation.RoutingTable) -> Documentation.URI   
    {
        let path:Documentation.URI.Path, 
            query:Documentation.URI.Query?
        if let namespace:Int = self.symbols[victim ?? witness].namespace
        {
            let (stem, leaf):([[UInt8]], [UInt8]) = self.stem(witness: witness, victim: victim)
            path = .init(
                root:  self.root(namespace:  namespace), 
                trunk: self.modules[namespace].id.trunk, 
                stem: stem, 
                leaf: leaf)
            switch routing.overloads[.init(witness: witness, victim: victim)]
            {
            case nil: 
                query = nil
            case .witness: 
                query = .init(witness: witness, victim: nil)
            case .crime:
                query = .init(witness: witness, victim: victim)
            }
        }
        else 
        {
            // mythical 
            path = .init(stem: [], leaf: [])
            switch routing.overloads[.init(witness: witness, victim: victim)]
            {
            case nil: 
                query = .init(witness: witness, victim: victim)
            case .witness: 
                fatalError("unreachable")
            case .crime:
                query = .init(witness: witness, victim: victim)
            }
        }
        return .init(base: .biome, path: path, query: query)
    }
    func format(uri:Documentation.URI, routing:Documentation.RoutingTable) -> String 
    {
        var utf8:[UInt8] = Documentation.URI.concatenate(normalized: uri.path.stem)
        if !uri.path.leaf.isEmpty
        {
            utf8.append(0x2e)
            utf8.append(contentsOf: uri.path.leaf)
        }
        
        var string:String = "\(routing[keyPath: uri.base.offset])\(String.init(decoding: utf8, as: Unicode.UTF8.self))"
        if let query:Documentation.URI.Query = uri.query 
        {
            string += "?overload=\(self.symbols[query.witness].id.string)"
            if let victim:Int = query.victim
            {
                string += "&self=\(self.symbols[victim].id)"
            }
        }
        return string
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
    func normalize<Path>(path:Path) -> [[UInt8]]
        where Path:Sequence, Path.Element:Sequence, Path.Element.Element == UInt8
    {
        var whatever:Bool = true 
        return self.normalize(path: path, changed: &whatever)
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

import Grammar

extension Documentation 
{
    /* struct Specialization 
    {
        struct ID:Hashable, Sendable 
        {
            private 
            let _witness:UInt32, 
                _victim:UInt32 // nil is UInt32.max
            
            static 
            func synthesized(from witness:Int, for victim:Int) -> Self 
            {
                let witness:UInt32   = .init(witness), 
                    victim:UInt32    = .init(victim)
                precondition(victim != .max)
                return .init(_witness: witness, _victim: victim)
            }
            static 
            func natural(_ symbol:Int) -> Self 
            {
                let symbol:UInt32   = .init(symbol)
                return .init(_witness: symbol, _victim: .max)
            }
            
            var witness:Int 
            {
                .init(self._witness)
            }
            var victim:Int? 
            {
                self._victim != .max ? .init(self._victim) : nil
            }
        }
        enum Flag
        {
            case unique
            case overloaded
            case overloadedScope
        }
        
        var flag:Flag 
        var stem:[UInt8]
        
        init(_ stem:[UInt8])
        {
            self.flag = .unique 
            self.stem = stem
        }
    }
    
    
    static 
    func _lookups() 
    {
        struct _Key 
        {
            let namespace:Int 
        }
    }
    
    
    

    mutating 
    func stem(disambiguating index:Dictionary<Specialization.ID, Specialization>.Index)
        -> [UInt8]
    {
        self.disambiguate(index)
        return self.specializations.values[index].stem
    }
    mutating 
    func stem(disambiguating index:Dictionary<Specialization.ID, Specialization>.Index, 
        while collision:(_ stem:[UInt8]) throws -> Void?)
        rethrows -> [UInt8]
    {
        while case _? = try collision(self.specializations.values[index].stem)
        {
            self.disambiguate(index)
        }
        return self.specializations.values[index].stem
    }
    private 
    func stem(symbol:Int, scope:Int?) -> [UInt8] 
    {
        guard let namespace:Int = self.symbols[scope ?? symbol].namespace 
        else 
        {
            // mythical symbol, can only be accessed through USR 
            return []
        }
        let symbol:Symbol       = self.symbols[symbol]
        let module:Module       = self.modules[namespace]
        let package:Package.ID  = self.packages[module.package].id
        
        var components:[String] 
        if case .community(let package) = _move(package)
        {
            components = [package, module.id.title]
        }
        else 
        {
            components =          [module.id.title]
        }
        let penultimate:String 
        let ultimate:String = symbol.title
        if  let scope:Int   = scope
        {
            penultimate     = self.symbols[scope].title
            components.append(contentsOf: self.symbols[scope].scope)
        } 
        else if let title:String = symbol.scope.last 
        {
            penultimate     = title
            components.append(contentsOf: symbol.scope.dropLast())
        }
        else 
        {
            // toplevel 
            components.append(ultimate)
            return URI.path(components.map(\.utf8))
        }
        
        return URI.path(components.map(\.utf8))
    }
    private mutating 
    func disambiguate(_ index:Dictionary<Specialization.ID, Specialization>.Index)
    {
        let specialization:Specialization.ID = self.specializations.keys[index]
        switch self.specializations.values[index].flag
        {
        case .unique:
            self.specializations.values[index].stem.append(
                contentsOf: "?overload=\(self.symbols[specialization.symbol].id.string)".utf8)
            self.specializations.values[index].flag = .overloaded 
        case .overloaded:
            guard let scope:Int = specialization.scope 
            else 
            {
                fallthrough
            }
            self.specializations.values[index].stem.append(
                contentsOf: "&self=\(self.symbols[scope].id.string)".utf8)
            self.specializations.values[index].flag = .overloadedScope 
        case .overloadedScope:
            fatalError("unreachable")
        }
    } */

}

extension Documentation.URI
{
    // these APIs assume the inputs are *not* percent-encoded at all! 
    /* static 
    func stem<Path>(normalizing path:Path) -> [UInt8]
        where Path:Collection, Path.Element:Sequence, Path.Element.Element == UInt8
    {
        // returned string is *empty* if `path` is empty, it is not '/'
        var utf8:[UInt8] = []
            utf8.reserveCapacity(path.reduce(0) { $0 + $1.underestimatedCount + 1 })
        for component:Path.Element in path 
        {
            utf8.append(0x2f) // '/'
            Self.component(normalizing: component, into: &utf8)
        }
        return utf8
    } */

}

extension Documentation
{    
    func resolve(uri:URI) -> URI.Resolved?
    {
        if  let query:URI.Query = uri.query, 
            let victim:Int = query.victim
        {
            return .resolution(witness: query.witness, victim: victim)
        }
        
        let witness:Int?                        = uri.query?.witness 
        var components:Array<[UInt8]>.Iterator  = uri.path.stem.makeIterator()
        
        guard let first:[UInt8] = components.next()
        else 
        {
            return witness.map { .resolution(witness: $0, victim: nil) } 
        }
        
        guard let root:UInt     = self.roots[first]
        else 
        {
            if let trunk:UInt   = self.trunks[first]
            {
                return self.resolve(namespace: trunk, 
                    stem: uri.path.stem.dropFirst(), 
                    leaf: uri.path.leaf, 
                    overload: witness)
            }
            else 
            {
                return witness.map { .resolution(witness: $0, victim: nil) }  
            }
        }
        if  let second:[UInt8]  = components.next(),
            let trunk:UInt      = self.trunks[second]
        {
            return self.resolve(namespace: trunk, 
                stem: uri.path.stem.dropFirst(2), 
                leaf: uri.path.leaf, 
                overload: witness)
        }
        guard   let stem:UInt   = self.greens[URI.concatenate(normalized: uri.path.stem.dropFirst())],
                let leaf:UInt   = self.greens[uri.path.leaf]
        else 
        {
            return witness.map { .resolution(witness: $0, victim: nil) }  
        }
        return .package(root, stem: stem, leaf: leaf)
    }
    private 
    func resolve(namespace:UInt, stem:ArraySlice<[UInt8]>, leaf:[UInt8], overload:Int?) -> URI.Resolved?
    {
        guard   let stem:UInt = self.greens[URI.concatenate(normalized: stem)],
                let leaf:UInt = self.greens[leaf]
        else 
        {
            return overload.map { .resolution(witness: $0, victim: nil) } 
        }
        return .namespaced(namespace, stem: stem, leaf: leaf, overload: overload)
    }
    
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
        var prefix:String.Iterator  = self.prefix.makeIterator()
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
        let leaf:Substring.UTF8View     = path[dot...].dropFirst()
        
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
                id = (nil, try? Grammar.parse(value, as: Biome.USR.Rule<Array<UInt8>.Index>.MangledName.self))
            
            case "overload": 
                switch try? Grammar.parse(value, as: Biome.USR.Rule<Array<UInt8>.Index>.self) 
                {
                case nil: 
                    changed = true 
                    continue  
                case .natural(let natural)?:
                    id = (natural, nil)
                
                case .synthesized(from: let witness, for: let victim)?:
                    id = (witness, victim)
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

import Grammar

extension Biome 
{
    public 
    struct Path:Hashable, Sendable
    {
        let group:String
        var disambiguation:Symbol.ID?
        
        var canonical:String 
        {
            if let id:Symbol.ID = self.disambiguation 
            {
                return "\(self.group)?overload=\(id.usr)"
            }
            else 
            {
                return self.group
            }
        }
        init(group:String, disambiguation:Symbol.ID? = nil)
        {
            self.group          = group
            self.disambiguation = disambiguation
        }
        init(prefix:[String], package:Package.ID) 
        {
            var unescaped:[String] = prefix 
            switch package 
            {
            case .swift: 
                // otherwise would collide with `swift/`
                unescaped.append("standard-library")
            case .community(let package):
                unescaped.append(package)
            }
            self.init(group: Self.normalize(lowercasing: unescaped))
        }
        init(prefix:[String], package:Package.ID, namespace:Module.ID) 
        {
            var unescaped:[String] = prefix 
            if case .community(let package) = package 
            {
                unescaped.append(package)
            }
            unescaped.append(namespace.title)
            self.init(group: Self.normalize(lowercasing: unescaped))
        }
        init(prefix:[String], _ breadcrumbs:Breadcrumbs, dot:Bool) 
        {
            self.init(prefix: prefix, 
                package: breadcrumbs.package, 
                namespace: breadcrumbs.graph.namespace, 
                path: breadcrumbs.path, 
                dot: dot)
        }
        init(prefix:[String], package:Package.ID, namespace:Module.ID, path:[String], dot:Bool) 
        {
            // to reduce the need for disambiguation suffixes, nested types and members 
            // use different syntax: 
            // Foo.Bar.baz(qux:) -> 'foo/bar.baz(qux:)' ["foo", "bar.baz(qux:)"]
            // 
            // global variables, functions, and operators (including scoped operators) 
            // start with a slash. so it’s 'prefix/swift/withunsafepointer(to:)', 
            // not `prefix/swift.withunsafepointer(to:)`
            var unescaped:[String]  = prefix 
            if case .community(let package) = package 
            {
                unescaped.append(package)
            }
            unescaped.append(namespace.title)
            if  dot, 
                let last:String     = path.last,
                let scope:String    = path.dropLast().last 
            {
                unescaped.append(contentsOf: path.dropLast(2))
                unescaped.append("\(scope).\(last)")
            }
            else 
            {
                unescaped.append(contentsOf: path)
            }
            self.init(group: Self.normalize(lowercasing: unescaped))
        }
    }
}
extension Biome.Path 
{
    static 
    func normalize<Group, Parameters>(_ group:Group, parameters:Parameters?) 
        -> (path:Self, redirected:Bool)
        where Group:StringProtocol, Parameters:StringProtocol
    {
        let disambiguation:Biome.Symbol.ID?
        let queryChanged:Bool  
        query:
        do
        {
            guard   let parameters:Parameters = parameters
            else 
            {
                disambiguation = nil 
                queryChanged = false 
                break query
            }
            guard   let parameters:[(key:String, value:String)] =
                    try? Grammar.parse(parameters.utf8, as: Rule<String.Index>.Query.self),
                    case ("overload", let string)? = parameters.first ,
                    let symbol:Biome.Symbol.ID = 
                    try? Grammar.parse(Self.normalize(string.utf8), as: Biome.Symbol.ID.Rule<Array<UInt8>.Index>.USR.self)
            else 
            {
                disambiguation = nil 
                queryChanged = true 
                break query
            }
            
            disambiguation  = symbol 
            queryChanged    = parameters.count > 1
        }
        let (group, pathChanged):([UInt8], Bool) = Self.normalize(lowercasing: group.utf8)
        let path:Self = .init(group: .init(decoding: group, as: Unicode.UTF8.self), 
            disambiguation: disambiguation)
        return (path, queryChanged || pathChanged)
    }
    
    static 
    func normalize<S>(_ utf8:S) -> [UInt8]
        where S:Sequence, S.Element == UInt8
    {
        self.normalize(utf8, mask: 0x00).utf8
    }
    static 
    func normalize<S>(lowercasing utf8:S) -> (utf8:[UInt8], changed:Bool) 
        where S:Sequence, S.Element == UInt8
    {
        self.normalize(utf8, mask: 0x20)
    }
    private static 
    func normalize<S>(_ string:S, mask:UInt8) -> (utf8:[UInt8], changed:Bool) 
        where S:Sequence, S.Element == UInt8
    {
        var utf8:[UInt8]        = []
        var iterator:S.Iterator = string.makeIterator()
        var changed:Bool        = false
        while let head:UInt8    = iterator.next() 
        {
            guard head != 0x2f // '/'
            else 
            {
                utf8.append(head)
                continue 
            }
            let byte:UInt8 
            if  head == 0x25 // '%'
            {
                guard   let first:UInt8     = iterator.next()
                else 
                {
                    utf8.append(head)
                    break 
                }
                guard   let second:UInt8    = iterator.next()
                else 
                {
                    utf8.append(head)
                    utf8.append(first)
                    break 
                }
                guard   let high:UInt8      = Grammar.Digit<Never, UInt8, UInt8>.ASCII.Hex.Anycase.parse(terminal: first),
                        let low:UInt8       = Grammar.Digit<Never, UInt8, UInt8>.ASCII.Hex.Anycase.parse(terminal: second)
                else 
                {
                    utf8.append(head)
                    utf8.append(first)
                    utf8.append(second)
                    continue 
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
        /* let string:String = .init(unsafeUninitializedCapacity: utf8.count)
        {
            let (_, index):(Array<UInt8>.Iterator, Int) = $0.initialize(from: utf8)
            return index - $0.startIndex 
        } */
        return (utf8, changed)
    }
    
    private static 
    func normalize<S>(lowercasing path:S) -> String 
        where S:Sequence, S.Element:StringProtocol
    {
        var utf8:[UInt8] = []
        for component:S.Element in path 
        {
            utf8.append(0x2f) // '/'
            for byte:UInt8 in component.utf8 
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
        }
        return String.init(unsafeUninitializedCapacity: utf8.count)
        {
            let (_, index):(Array<UInt8>.Iterator, Int) = $0.initialize(from: utf8)
            return index - $0.startIndex 
        }
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
}

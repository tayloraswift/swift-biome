import Resource
import JSON

public 
struct Documentation:Sendable
{
    struct URI:Equatable, Sendable 
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
            //  '/'
            // case root 
            //  '/' 'swift-standard-library'
            //  '/' 'swift-standard-library' '/search' ( '.' 'json' )
            case package(Int, stem:UInt, leaf:UInt)
            //  '/' 'swift'
            //  '/' 'swift-nio/niocore'
            //  '/' 'swift-nio/niocore' '/foo/bar' ( '.' 'baz(_:)' ) ( '?overload=' 's:xxx' )
            case namespaced(UInt, stem:UInt, leaf:UInt, overload:Int?)
            //  '?overload=' 's:xxx' '&self=' 's:yyy'
            //  note: victim can be `nil` if the symbol is mythical, and is not synthesized
            case resolution(witness:Int, victim:Int?)
        }
        enum Overloading
        {
            case witness   
            case crime
        }
        struct Path:Equatable, Sendable 
        {
            var stem:[[UInt8]], 
                leaf:[UInt8]
        }
        struct Query:Hashable, Sendable 
        {
            var witness:Int, 
                victim:Int?
        }
        var path:Path
        var query:Query?
        
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
    
    enum Index:Hashable, Sendable 
    {
        case packageSearchIndex(Int)
        case package(Int)
        case module(Int)
        case symbol(Int, victim:Int?)
        
        case ambiguous
    }
    
    let prefix:String
    let biome:Biome
    let packages:[Article], 
        modules:[Article], 
        symbols:[Article] 
    
    private(set)
    var _search:[Resource] 
    private(set)
    var overloads:[Int: URI.Overloading],
        routes:[URI.Resolved: Index],
        greens:[[UInt8]: UInt]
    
    public 
    init(prefix:String, packages:[Biome.Package.ID: [String]], 
        loader load:(_ package:Biome.Package.ID, _ module:String) async throws -> Resource) async throws 
    {
        let (biome, comments):(Biome, [String]) = try await Biome.load(packages: packages, loader: load)
        // render articles 
        let symbols:[Article]   = zip(biome.symbols.indices, _move(comments)).map 
        {
            biome.article(symbol: $0.0, comment: $0.1) 
        }
        let modules:[Article]   = biome.modules.indices.map 
        {
            biome.article(module: $0, comment: "") 
        }
        let packages:[Article]  = biome.packages.indices.map 
        {
            biome.article(package: $0, comment: "")
        }
        self.init(prefix: prefix, biome: _move(biome), packages: packages, modules: modules, symbols: symbols)
    }
    init(prefix:String, biome:Biome, packages:[Article], modules:[Article], symbols:[Article])
    {
        self._search    = [] 
        self.packages   = packages 
        self.modules    = modules
        self.symbols    = symbols
        self.prefix     = prefix 
        self.biome      = biome
        
        self.overloads  = [:]
        self.routes     = [:]
        // TODO: we need to account for colliding module names under case folding
        self.greens     = [:]
        
        for index:Int in self.biome.packages.indices
        {
            self.publish(packageSearchIndex: index)
            self.publish(package: index)
        }
        for index:Int in self.biome.modules.indices
        {
            self.publish(module: index)
        }
        for index:Int in self.biome.symbols.indices
        {
            self.publish(witness: index, victim: nil)
            for member:Int in self.biome.symbols[index].relationships.members ?? []
            {
                if  let interface:Int = self.biome.symbols[member].parent, 
                        interface != index 
                {
                    self.publish(witness: member, victim: index)
                }
            }
        }
        
        self._search = self.biome.packages.map(self.searchIndex(for:))
        
        var _memory:Int 
        {
            self.modules.reduce(0)
            {
                $0 + $1.size
            }
            +
            self.symbols.reduce(0)
            {
                $0 + $1.size
            }
        }
        Swift.print("rendered \(self.modules.count + self.symbols.count) articles (\(_memory >> 10) KB)")
        
        for module:Biome.Module in self.biome.modules
        {
            var errors:Int = 0
            for index:Int in module.allSymbols
            {
                errors += self.symbols[index].errors.count
            }
            if errors > 0 
            {
                Swift.print("note: \(errors) linter warnings(s) in module '\(module.id.string)'")
            }
        }
    }
    
    private mutating 
    func publish(packageSearchIndex package:Int) 
    {
        let (stem, leaf):([[UInt8]], leaf:[UInt8]) = self.stem(packageSearchIndex: package)
        self.publish(.package(package), disambiguated: .package(package, 
            stem: self.register(stem: stem), 
            leaf: self.register(leaf: leaf)))
    }
    private mutating 
    func publish(package:Int) 
    {
        let empty:UInt          = self.register(leaf: [])
        let key:URI.Resolved    = .package(package, stem: empty, leaf: empty)
        self.publish(.package(package), disambiguated: key)
    }
    private mutating 
    func publish(module:Int) 
    {
        let empty:UInt          = self.register(leaf: [])
        let key:URI.Resolved    = .namespaced(
                    self.register(leaf: URI.encode(component: self.biome.modules[module].id.title.utf8)), 
            stem:   empty, 
            leaf:   empty, 
            overload: nil)
        self.publish(.module(module), disambiguated: key)
    }
    private mutating 
    func publish(witness:Int, victim:Int?) 
    {
        var selector:URI.Resolved
        if let namespace:Int = self.biome.symbols[victim ?? witness].namespace
        {
            let (stem, leaf):([[UInt8]], leaf:[UInt8]) = self.stem(witness: witness, victim: victim)
            selector = .namespaced(
                        self.register(leaf: URI.encode(component: self.biome.modules[namespace].id.title.utf8)), 
                stem:   self.register(stem: stem), 
                leaf:   self.register(leaf: leaf), 
                overload: nil)
        }
        else 
        {
            // mythical 
            selector = .resolution(witness: witness, victim: nil)
        }
        while let index:Dictionary<URI.Resolved, Index>.Index = self.routes.index(forKey: selector)
        {
            switch self.routes.values[index] 
            {
            case .symbol(let witness, victim: let victim):
                // prevents us from accidentally filling in the ambiguous slot in 
                // a subsequent call
                self.routes.values[index]   = .ambiguous 
                // this will never crash unless `self.disambiguate(_:with:victim)`
                // does, because it always adds a parameter on its non-trapping paths 
                var location:URI.Resolved   = self.routes.keys[index]
                let amount:URI.Overloading  = self.disambiguate(&location, with: witness, victim: victim)
                self.overloads.updateValue(amount, forKey: witness)
                self.publish(.symbol(witness, victim: victim), disambiguated: location)
                fallthrough
            
            case .ambiguous:
                let _:URI.Overloading       = self.disambiguate(&selector, with: witness, victim: victim)
                
            default: 
                fatalError("unreachable")
            }
        }
        self.publish(.symbol(witness, victim: victim), disambiguated: selector)
    }
    private mutating 
    func publish(_ index:Index, disambiguated key:URI.Resolved)
    {
        if let colliding:Index = self.routes.updateValue(index, forKey: key)
        {
            fatalError("colliding paths \(key) -> (\(index), \(colliding))")
        }
    }
    private mutating 
    func disambiguate(_ selector:inout URI.Resolved, with witness:Int, victim:Int?) -> URI.Overloading
    {
        switch (selector, victim) 
        {
        // things we can disambiguate
        case    (                                  .resolution(witness: witness, victim: nil), let victim?),
                (.namespaced(_,             stem: _, leaf: _, overload: witness),              let victim?):
            selector =                             .resolution(witness: witness,           victim: victim)
            return .crime 
        case    (.namespaced(let namespace, stem: let stem, leaf: let leaf, overload: nil),    _):
            selector = .namespaced(namespace, stem:   stem, leaf:     leaf, overload: witness)
            return .witness 
            
        case (let base, let victim?):
            Swift.print(base, witness, victim)
            Swift.print(self.biome.symbols[witness].module as Any)
            Swift.print(self.biome.symbols[witness].bystander as Any)
            Swift.print(self.biome.symbols[witness].id)
            Swift.print(self.biome.symbols[victim].module as Any)
            Swift.print(self.biome.symbols[victim].bystander as Any)
            Swift.print(self.biome.symbols[victim].id)
            fallthrough
        default: 
            fatalError("unreachable")
        }
    }
    
    private mutating 
    func register(stem:[[UInt8]]) -> UInt
    {
        self.register(leaf: URI.concatenate(normalized: stem))
    }
    private mutating 
    func register(leaf:[UInt8]) -> UInt 
    {
        var counter:UInt = .init(self.greens.count)
        self.greens.merge(CollectionOfOne<([UInt8], UInt)>.init((leaf, counter))) 
        { 
            (current:UInt, _:UInt) in 
            counter = current 
            return current 
        }
        return counter
    }
    
    // does not include the package name!
    private 
    func stem(packageSearchIndex package:Int) -> (stem:[[UInt8]], leaf:[UInt8])
    {
        ([[UInt8].init("search".utf8)], [UInt8].init("json".utf8))
    }
    private 
    func trunk(package:Int) -> [[UInt8]]
    {
        [URI.encode(component: self.biome.packages[package].id.name.utf8)]
    }
    private 
    func trunk(module:Int) -> [[UInt8]]
    {
        let module:Biome.Module = self.biome.modules[module]
        if case .community(let package) = self.biome.packages[module.package].id
        {
            return [URI.encode(component: package.utf8), URI.encode(component: module.id.title.utf8)]
        }
        else 
        {
            return [                                     URI.encode(component: module.id.title.utf8)]
        }
    }
    // this path does not contain the module or prefix!
    private 
    func stem(witness:Int, victim:Int?) -> (stem:[[UInt8]], leaf:[UInt8])
    {
        var stem:[[UInt8]] = []
        for component:String in self.biome.symbols[victim ?? witness].scope
        {
            stem.append(URI.encode(component: component.utf8))
        }
        if let victim:Int = victim 
        {
            stem.append(URI.encode(component: self.biome.symbols[victim].title.utf8))
        }
        
        let title:String    = self.biome.symbols[witness].title
        switch self.biome.symbols[witness].kind 
        {
        case    .associatedtype, .typealias, .enum, .struct, .class, .actor, .protocol:
            stem.append(URI.encode(component: title.utf8))
            return (stem: stem, leaf: [])
        
        case    .case, .initializer, .deinitializer, 
                .typeSubscript, .instanceSubscript, 
                .typeProperty, .instanceProperty, 
                .typeMethod, .instanceMethod, 
                .var, .func, .operator:
            return (stem: stem, leaf: URI.encode(component: title.utf8))
        }
    }
    
    func uri(packageSearchIndex package:Int) -> URI  
    {
        let (stem, leaf):([[UInt8]], [UInt8]) = self.stem(packageSearchIndex: package)
        return .init(path: .init(stem: self.trunk(package: package) + stem, leaf: leaf), query: nil)
    }
    func uri(package:Int) -> URI  
    {
        .init(path: .init(stem: self.trunk(package: package), leaf: []), query: nil)
    }
    func uri(module:Int) -> URI 
    {
        .init(path: .init(stem: self.trunk(module: module), leaf: []), query: nil)
    }
    func uri(witness:Int, victim:Int?) -> URI   
    {
        let path:URI.Path
        if let namespace:Int = self.biome.symbols[victim ?? witness].namespace
        {
            let (stem, leaf):([[UInt8]], [UInt8]) = self.stem(witness: witness, victim: victim)
            path = .init(stem: self.trunk(module: namespace) + stem, leaf: leaf)
        }
        else 
        {
            // mythical 
            path = .init(stem: [], leaf: [])
        }
        switch self.overloads[witness]
        {
        case nil: 
            return .init(path: path, query: nil)
        case .witness: 
            return .init(path: path, query: .init(witness: witness, victim: nil))
        case .crime:
            return .init(path: path, query: .init(witness: witness, victim: victim))
        }
    }
    
    func print(uri:URI) -> String 
    {
        var utf8:[UInt8] = URI.concatenate(normalized: uri.path.stem)
        if !uri.path.leaf.isEmpty
        {
            utf8.append(0x2e)
            utf8.append(contentsOf: uri.path.leaf)
        }
        
        var string:String = "\(self.prefix)\(String.init(decoding: utf8, as: Unicode.UTF8.self))"
        if let query:URI.Query = uri.query 
        {
            string += "?overload=\(self.biome.symbols[query.witness].id.string)"
            if let victim:Int = query.victim
            {
                string += "&self=\(self.biome.symbols[victim].id)"
            }
        }
        return string
    }

    public 
    subscript(uri:(path:String, query:Substring?), referrer referrer:(path:String, query:Substring?)? = nil)
        -> (content:Resource?, canonical:String)?
    {
        let (uri, redirect):(URI, Bool) = self.normalize(uri: uri)
        
        var _filter:[Biome.Package.ID] 
        {
            self.biome.packages.map(\.id)
        }
        Swift.print(uri)
        guard let resolved:URI.Resolved = self.resolve(uri: uri)
        else 
        {
            return nil 
        }
        Swift.print(resolved)
        let canonical:URI, 
            resource:Resource 
        switch self.routes[resolved]  
        {
        case nil, .ambiguous: 
            return nil 
        case .packageSearchIndex(let index):
            canonical   = self.uri(packageSearchIndex: index)
            resource    = self._search[index]
        
        case .package(let index):
            canonical   = self.uri(package: index)
            resource    = self.page(package: index, filter: _filter)
        case .module(let index):
            canonical   = self.uri(module: index)
            resource    = self.page(module: index, filter: _filter)
        case .symbol(let index, victim: let victim):
            canonical   = self.uri(witness: index, victim: victim)
            resource    = self.page(witness: index, victim: victim, filter: _filter)
        }
        
        return ((uri, redirect) == (canonical, false) ? resource : nil, self.print(uri: canonical))
    }
    

    

    /// the `group` is the full URL path, without the query, and including 
    /// the beginning slash '/' and path prefix. 
    /// the path *must* be normalized with respect to slashes, but it 
    /// *must not* be percent-decoded. (otherwise the user may be sent into 
    /// an infinite redirect loop.)
    ///
    /// '/reference/swift-package/somemodule/foo/bar.baz%28_%3A%29':    OK (canonical page for `SomeModule.Foo.Bar.baz(_:)`)
    /// '/reference/swift-package/somemodule/foo/bar.baz(_:)':          OK (301 redirect to `SomeModule.Foo.Bar.baz(_:)`)
    /// '/reference/swift-package/SomeModule/FOO/BAR.BAZ(_:)':          OK (301 redirect to `SomeModule.Foo.Bar.baz(_:)`)
    /// '/reference/swift-package/somemodule/foo/bar%2Ebaz%28_%3A%29':  OK (301 redirect to `SomeModule.Foo.Bar.baz(_:)`)
    /// '/reference/swift-package/somemodule/foo//bar.baz%28_%3A%29':   Error (slashes not normalized)
    ///
    /// note: the URL of a page for an operator containing a slash '/' *must*
    /// be percent-encoded; Biome will not be able to redirect it to the 
    /// correct canonical URL. 
    ///
    /// note: the URL path is case-insensitive, but the disambiguation query 
    /// *is* case-sensitive. the `disambiguation` parameter should include 
    /// the mangled name only, without the `?overload=` part. if you provide 
    /// a valid disambiguation query, the URL path can be complete garbage; 
    /// Biome will respond with a 301 redirect to the correct page.
}
/* extension URI
{
    static 
    func normalize(query:Substring) -> Biome.USR
    {
        let disambiguation:Biome.Symbol.ID?
        let queryChanged:Bool  
        query:
        do
        {
            guard   let parameters:[(key:String, value:String)] =
                    try? Grammar.parse(parameters.utf8, as: Rule<String.Index>.Query.self),
                    case ("overload", let string)? = parameters.first,
                    let usr:USR = try? Grammar.parse(Self.normalize(string.utf8), as: Biome.USR.Rule<Array<UInt8>.Index>.self)
            else 
            {
                disambiguation = nil 
                queryChanged = true 
                break query
            }
            
            disambiguation  = symbol 
            queryChanged    = parameters.count > 1
        }
    }
    
    static 
    func normalize<Group, Parameters>(_ group:Group, parameters:Parameters?) 
        -> (group:String, changed:Bool)
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
                    try? Grammar.parse(Self.normalize(string.utf8), as: Biome.USR.Rule<Array<UInt8>.Index>.self)
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
} */

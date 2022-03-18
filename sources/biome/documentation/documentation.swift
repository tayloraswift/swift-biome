import Resource
import JSON

extension Biome 
{
    fileprivate 
    func stem(packageSearchIndex package:Int) -> [[UInt8]]
    {
        [[UInt8].init("search".utf8)]
    }
    fileprivate 
    func leaf(packageSearchIndex package:Int) -> [UInt8]
    {
        [UInt8].init("json".utf8)
    }
    fileprivate 
    func root(package:Int) -> [UInt8]
    {
        Documentation.URI.encode(component: self.packages[package].id.name.utf8)
    }
    fileprivate 
    func root(namespace module:Int) -> [UInt8]
    {
        if case .community(let package) = self.packages[self.modules[module].package].id
        {
            return Documentation.URI.encode(component: package.utf8)
        }
        else 
        {
            return []
        }
    }
    fileprivate 
    func trunk(namespace module:Int) -> [UInt8]
    {
        Documentation.URI.encode(component: self.modules[module].id.title.utf8)
    }
    fileprivate 
    func stem(witness:Int, victim:Int?) -> (stem:[[UInt8]], leaf:[UInt8])
    {
        var stem:[[UInt8]] = []
        for component:String in self.symbols[victim ?? witness].scope
        {
            stem.append(Documentation.URI.encode(component: component.utf8))
        }
        if let victim:Int = victim 
        {
            stem.append(Documentation.URI.encode(component: self.symbols[victim].title.utf8))
        }
        
        let title:String = self.symbols[witness].title
        switch self.symbols[witness].kind 
        {
        case    .associatedtype, .typealias, .enum, .struct, .class, .actor, .protocol:
            stem.append(Documentation.URI.encode(component: title.utf8))
            return (stem: stem, leaf: [])
        
        case    .case, .initializer, .deinitializer, 
                .typeSubscript, .instanceSubscript, 
                .typeProperty, .instanceProperty, 
                .typeMethod, .instanceMethod, 
                .var, .func, .operator:
            return (stem: stem, leaf: Documentation.URI.encode(component: title.utf8))
        }
    }
    
    
    // uris 
    fileprivate 
    func uri(packageSearchIndex package:Int) -> Documentation.URI  
    {
        return .init(path: .init(
            root: self.root(package: package), 
            stem: self.stem(packageSearchIndex: package), 
            leaf: self.leaf(packageSearchIndex: package)), 
            query: nil)
    }
    fileprivate 
    func uri(package:Int) -> Documentation.URI  
    {
        .init(path: .init(
            root: self.root(package: package), 
            stem: [], 
            leaf: []), 
            query: nil)
    }
    fileprivate 
    func uri(module:Int) -> Documentation.URI 
    {
        .init(path: .init(
            root:  self.root(namespace:  module), 
            trunk: self.trunk(namespace: module), 
            stem: [], 
            leaf: []), 
            query: nil)
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
                trunk: self.trunk(namespace: namespace), 
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
        return .init(path: path, query: query)
    }
    func print(prefix:String, uri:Documentation.URI) -> String 
    {
        var utf8:[UInt8] = Documentation.URI.concatenate(normalized: uri.path.stem)
        if !uri.path.leaf.isEmpty
        {
            utf8.append(0x2e)
            utf8.append(contentsOf: uri.path.leaf)
        }
        
        var string:String = "\(prefix)\(String.init(decoding: utf8, as: Unicode.UTF8.self))"
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
public 
struct Documentation:Sendable
{
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
            //  '/'
            // case root 
            //  '/' 'swift-standard-library'
            //  '/' 'swift-standard-library' '/search' ( '.' 'json' )
            case package(UInt, stem:UInt, leaf:UInt)
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
        enum Redirect
        {
            case temporary 
            case permanent
        }
        struct Path:Equatable, CustomStringConvertible, Sendable 
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
        
        var path:Path
        var query:Query?
        
        var description:String 
        {
            "\(self.path)\(self.query?.description ?? "")"
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
    enum Index:Hashable, Sendable 
    {
        case packageSearchIndex(Int)
        case package(Int)
        case module(Int)
        case symbol(Int, victim:Int?)
        
        case ambiguous
    }
    
    struct Table<Key> where Key:Hashable 
    {
        private 
        var table:[Key: UInt]
        
        init() 
        {
            self.table = [:]
        }
        
        subscript(key:Key) -> UInt? 
        {
            _read 
            {
                yield self.table[key]
            }
            _modify
            {
                yield &self.table[key]
            }
        }
        
        mutating 
        func register(_ key:Key) -> UInt 
        {
            var counter:UInt = .init(self.table.count)
            self.table.merge(CollectionOfOne<(Key, UInt)>.init((key, counter))) 
            { 
                (current:UInt, _:UInt) in 
                counter = current 
                return current 
            }
            return counter
        }
    }
    struct RoutingTable 
    {
        let prefix:String
        private(set)
        var rootless:Set<UInt>, // trunk keys
            operators:Set<UInt>, // leaf keys
            overloads:[URI.Query: URI.Overloading],
            routes:[URI.Resolved: Index],
            greens:Table<[UInt8]>, 
            trunks:Table<[UInt8]>, 
            roots:Table<[UInt8]>
        
        init(prefix:String) 
        {
            self.prefix     = prefix 
            
            self.rootless   = [ ]
            self.operators  = [ ]
            self.overloads  = [:]
            self.routes     = [:]
            self.greens     = .init()
            self.trunks     = .init()
            self.roots      = .init()
        }
        
        mutating 
        func populate(from biome:Biome)
        {
            for index:Int in biome.packages.indices
            {
                self.publish(packageSearchIndex: index, from: biome)
                self.publish(package: index, from: biome)
                // set up redirects 
                if case .swift = biome.packages[index].id 
                {
                    for name:String in 
                    [
                        "standard-library", 
                        "swift-stdlib", 
                        "stdlib"
                    ]
                    {
                        self.publish(package: index, under: [UInt8].init(name.utf8))
                    }
                }
            }
            for index:Int in biome.modules.indices
            {
                self.publish(module: index, from: biome)
            }
            for index:Int in biome.symbols.indices
            {
                self.publish(witness: index, victim: nil, from: biome)
                for member:Int in biome.symbols[index].relationships.members ?? []
                {
                    if  let interface:Int = biome.symbols[member].parent, 
                            interface != index 
                    {
                        self.publish(witness: member, victim: index, from: biome)
                    }
                }
            }
        }
        
        private mutating 
        func publish(packageSearchIndex package:Int, from biome:Biome) 
        {
            self.publish(.packageSearchIndex(package), 
                disambiguated: .package(self.roots.register(biome.root(package: package)), 
                stem:   self.greens.register(URI.concatenate(normalized: biome.stem(packageSearchIndex: package))), 
                leaf:   self.greens.register(biome.leaf(packageSearchIndex: package))))
        }
        private mutating 
        func publish(package:Int, from biome:Biome) 
        {
            self.publish(package: package, under: biome.root(package: package))
        }
        private mutating 
        func publish(package:Int, under name:[UInt8]) 
        {
            let empty:UInt = self.greens.register([])
            self.publish(.package(package), 
                disambiguated: .package(self.roots.register(name), 
                stem:   empty, 
                leaf:   empty))
        }
        private mutating 
        func publish(module:Int, from biome:Biome) 
        {
            let empty:UInt = self.greens.register([])
            let trunk:UInt = self.trunks.register(biome.trunk(namespace: module))
            self.publish(.module(module), 
                disambiguated: .namespaced(trunk, 
                stem:   empty, 
                leaf:   empty, 
                overload: nil))
            // whitelist standard library modules 
            if case .swift = biome.packages[biome.modules[module].package].id 
            {
                self.rootless.insert(trunk)
            }
        }
        private mutating 
        func publish(witness:Int, victim:Int?, from biome:Biome) 
        {
            var selector:URI.Resolved, 
                amount:URI.Overloading? = nil
            if let namespace:Int = biome.symbols[victim ?? witness].namespace
            {
                let normalized:(stem:[[UInt8]], leaf:[UInt8]) = biome.stem(witness: witness, victim: victim)
                let trunk:UInt  = self.trunks.register(biome.trunk(namespace: namespace))
                let stem:UInt   = self.greens.register(URI.concatenate(normalized: normalized.stem))
                let leaf:UInt   = self.greens.register(normalized.leaf)
                // whitelist operator leaves so they can recieve permanent redirects 
                // instead of temporary redirects 
                if case .operator = biome.symbols[witness].kind 
                {
                    self.operators.insert(leaf)
                }
                selector = .namespaced(trunk, stem: stem, leaf: leaf, overload: nil)
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
                    self.overloads.updateValue(amount, forKey: .init(witness: witness, victim: victim))
                    self.publish(.symbol(witness, victim: victim), disambiguated: location)
                    fallthrough
                
                case .ambiguous:
                    amount = self.disambiguate(&selector, with: witness, victim: victim)
                    
                default: 
                    fatalError("unreachable")
                }
            }
            if let amount:URI.Overloading  = amount
            {
                self.overloads.updateValue(amount, forKey: .init(witness: witness, victim: victim))
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
            default: 
                fatalError("unreachable")
            }
        }
        
        // uri resolution 
        func resolve(overload witness:Int, self victim:Int) -> Index? 
        {
            self.routes[.resolution(witness: witness, victim: victim)]
        }
        func resolve(mythical witness:Int) -> Index?
        {
            self.routes[.resolution(witness: witness, victim: nil)]
        }
        func resolve(path:URI.Path, overload witness:Int?) -> (index:Index, assigned:Bool)? 
        {
            var components:Array<[UInt8]>.Iterator  = path.stem.makeIterator()
            guard let first:[UInt8]     = components.next()
            else 
            {
                return nil
            }
            guard let root:UInt         = self.roots[first]
            else 
            {
                if  let trunk:UInt  = self.trunks[first], 
                    let (index, assigned):(Index, assigned:Bool) = self.resolve(namespace: trunk, 
                    stem: path.stem.dropFirst(), 
                    leaf: path.leaf, 
                    overload: witness)
                {
                    // modules names are currently unique, but only make this a permanent 
                    // redirect if it’s a standard library module
                    return (index, assigned ? self.rootless.contains(trunk) : false)
                }
                else 
                {
                    return nil
                }
            }
            if  let second:[UInt8]  = components.next(),
                let trunk:UInt      = self.trunks[second]
            {
                return self.resolve(namespace: trunk, 
                    stem: path.stem.dropFirst(2), 
                    leaf: path.leaf, 
                    overload: witness)
            }
            guard   let stem:UInt   = self.greens[URI.concatenate(normalized: path.stem.dropFirst())],
                    let leaf:UInt   = self.greens[path.leaf]
            else 
            {
                return nil
            }
            return self.routes[.package(root, stem: stem, leaf: leaf)].map { ($0, true) }
        }
        private 
        func resolve(namespace:UInt, stem:ArraySlice<[UInt8]>, leaf:[UInt8], overload:Int?) -> (index:Index, assigned:Bool)?
        {
            if  let stemKey:UInt    = self.greens[URI.concatenate(normalized: stem)],
                let leafKey:UInt    = self.greens[leaf], 
                let index:Index     = self.routes[.namespaced(namespace, stem: stemKey, leaf: leafKey, overload: overload)]
            {
                return (index, true)
            }
            // for backwards-compatibility, try reinterpreting the last stem 
            // component as a leaf. only do this if we don’t already have a leaf. 
            // since swift prohibits operators from containing a dot '.' unless 
            // they begin with a dot, we will not miss any operator redirects.
            //
            // note that this is not where the range operator redirect happens; 
            // that is handled by `normalize(path:changed:)`, since it generates an 
            // empty stem component at the end.
            guard leaf.isEmpty,
                let last:[UInt8]    = stem.last,
                let stemKey:UInt    = self.greens[URI.concatenate(normalized: stem.dropLast())], 
                let leafKey:UInt    = self.greens[last]
            else 
            {
                return nil
            }
            let fallback:URI.Resolved = .namespaced(namespace, stem: stemKey, leaf: leafKey, overload: overload)
            if  self.operators.contains(leafKey),
                let index:Index     = self.routes[fallback]
            {
                // only consider this a permanent redirect if the fallback leaf is 
                // an operator
                return (index, true)
            }
            else if stem.dropFirst().isEmpty,
                let index:Index     = self.routes[fallback]
            {
                // global funcs and vars. these are temporary redirects
                return (index, false)
            }
            else 
            {
                return nil
            }
        }
    }
    
    let biome:Biome 
    let routing:RoutingTable
    let packages:[Article], 
        modules:[Article], 
        symbols:[Article] 
    
    private(set)
    var search:[Resource] 

    
    public 
    init(prefix:String, products descriptors:[Biome.Package.ID: [Biome.Target]], 
        loader load:(_ package:Biome.Package.ID, _ path:[String], _ type:Resource.Text) 
        async throws -> Resource) 
        async throws 
    {
        let (products, targets):([Biome.Product], [Biome.Target]) = Biome.flatten(
            descriptors: descriptors)
        let (biome, comments):(Biome, [String]) = try await Biome.load(
            products: products, 
            targets: targets, 
            loader: load)
        
        Swift.print("starting article loading")
        var articles:[String] = []
        for package:Biome.Package in biome.packages 
        {
            for module:Biome.Target in targets[package.modules]
            {
                for path:[String] in module.articles 
                {
                    // TODO: handle versioning
                    switch try await load(package.id, ["\(module.id.string).docc"] + path, .plain)
                    {
                    case    .text   (let string, type: .plain, version: _):
                        articles.append(string)
                    case    .bytes  (let bytes,  type: .plain, version: _):
                        articles.append(String.init(decoding: bytes, as: Unicode.UTF8.self))
                    case    .text   (_, type: let type, version: _),
                            .bytes  (_, type: let type, version: _):
                        throw Biome.ResourceTypeError.init(type.description, expected: Resource.Text.plain.description)
                    case    .binary (_, type: let type, version: _):
                        throw Biome.ResourceTypeError.init(type.description, expected: Resource.Text.plain.description)
                    }
                }
            }
        }
        Swift.print("finished article loading")
        
        var routing:RoutingTable = .init(prefix: prefix)
            routing.populate(from: biome)
        
        // render articles 
        for article:String in articles
        {
            var renderer:MarkdownDiagnostic.Renderer = .init(biome: biome, routing: routing)
            let (summary, toplevel):(_, _) = renderer.render(comment: article)
            Swift.print("---")
            for error:MarkdownDiagnostic in renderer.errors 
            {
                Swift.print(error)
            }
        }
        
        self.symbols    = zip(biome.symbols, _move(comments)).map 
        {
            if case _?  = $0.0.commentOrigin 
            {
                // don’t re-render duplicated docs 
                return .init()
            }
            else 
            {
                return .init(comment: $0.1, biome: biome, routing: routing)
            }
        }
        self.modules    = .init(repeating: .init(), count: biome.modules.count)
        self.packages   = .init(repeating: .init(), count: biome.packages.count)
        
        self.search     = biome.searchIndices(routing: routing)
        self.routing    = routing
        self.biome      = _move(biome)
        
        // verify that every crime is reachable without redirects 
        /* if  true 
        {
            for index:Int in self.biome.symbols.indices
            {
                Swift.print("testing \((witness: index, victim: Optional<Int>.none))")
                self.validate(uri: self.uri(witness: index, victim: nil))
                for member:Int in self.biome.symbols[index].relationships.members ?? []
                {
                    if  let interface:Int = self.biome.symbols[member].parent, 
                            interface != index 
                    {
                        Swift.print("testing \((witness: member, victim: index))")
                        self.validate(uri: self.uri(witness: member, victim: index))
                    }
                }
            }
        } */
        
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
        self.biome.print(prefix: self.routing.prefix, uri: uri)
    }
    
    private 
    func validate(uri:URI) 
    {
        let uri:String = self.print(uri: uri)
        switch self[uri]
        {
        case nil, .none?: 
            fatalError("uri '\(uri)' can never be accessed")
        case .maybe(canonical: _, at: let location), .found(canonical: _, at: let location): 
            fatalError("uri '\(uri)' always redirects to '\(location)'")
        case .matched:
            break 
        }
    }

    public 
    subscript(uri:String, referrer _:String? = nil) -> StaticResponse?
    {
        let response:(payload:Resource, location:URI)?,
            redirect:(always:Bool, temporarily:Bool), 
            normalized:URI 
        
        (normalized, redirect.always) = self.normalize(uri: uri)
        
        if  let query:URI.Query     = normalized.query, 
            let victim:Int          = query.victim, 
            let index:Index         = self.routing.resolve(overload: query.witness, self: victim)
        {
            response                = self[index]
            redirect.temporarily    = false 
        }
        else if let (index, assigned):(Index, assigned:Bool) = 
            self.routing.resolve(path: normalized.path, overload: normalized.query?.witness)
        {
            response                = self[index]
            redirect.temporarily    = !assigned
        }
        else if let witness:Int     = normalized.query?.witness,
                let index:Index     = self.routing.resolve(mythical: witness)
        {
            response                = self[index]
            redirect.temporarily    = false
        }
        else 
        {
            return nil
        }
        guard let response:(payload:Resource, location:URI) = response 
        else 
        {
            //return .none(self.notFound)
            return nil
        }
        
        let location:String     = self.print(uri: response.location)
        // TODO: fixme
        let canonical:String    = location 
        
        switch (matches: response.location == normalized, redirect: redirect) 
        {
        case    (matches:  true, redirect: (always: false, temporarily: _)):
            // ignore temporary-redirect flag, since temporary redirects should never match 
            return .matched(canonical: canonical, response.payload)
        case    (matches:  true, redirect: (always:  true, temporarily: _)),
                (matches: false, redirect: (always:     _, temporarily: false)):
            return   .found(canonical: canonical, at: location)
        case    (matches: false, redirect: (always:     _, temporarily:  true)):
            return   .maybe(canonical: canonical, at: location)
        }
    }
    
    // TODO: implement disambiguation pages so this can become non-optional
    subscript(index:Index) -> (payload:Resource, location:URI)?
    {
        var _filter:[Biome.Package.ID] 
        {
            self.biome.packages.map(\.id)
        }
        let location:URI, 
            resource:Resource 
        switch index
        {
        case .ambiguous: 
            return nil
        case .packageSearchIndex(let index):
            location = self.uri(packageSearchIndex: index)
            resource = self.search[index]
        
        case .package(let index):
            location = self.uri(package: index)
            resource = self.page(package: index, filter: _filter)
        case .module(let index):
            location = self.uri(module: index)
            resource = self.page(module: index, filter: _filter)
        case .symbol(let index, victim: let victim):
            location = self.uri(witness: index, victim: victim)
            resource = self.page(witness: index, victim: victim, filter: _filter)
        }
        return (resource, location)
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

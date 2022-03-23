extension Documentation 
{
    struct RoutingTable 
    {
        let base:(biome:String, learn:String)
        
        let whitelist:Set<Int> // module indices
        private(set)
        var greenlist:Set<UInt>, // leaf keys
            overloads:[URI.Query: URI.Overloading],
            routes:[URI.Resolved: Index],
            greens:[[UInt8]: UInt]
        let trunks:[[UInt8]: Int], 
            roots:[[UInt8]: Int]
        
        init(bases:[URI.Base: String], biome:Biome) 
        {
            self.base.biome = bases[.biome, default: "/biome"]
            self.base.learn = bases[.learn, default: "/learn"]
            
            var whitelist:Set<Int>      = [ ]
            var roots:[[UInt8]: Int]    = [:]
            for index:Int in biome.packages.indices
            {
                roots[biome.root(package: index)] = index
                
                if case .swift = biome.packages[index].id 
                {
                    // redirect standard library names 
                    for name:String in 
                    [
                        "standard-library", 
                        "swift-stdlib", 
                        "stdlib"
                    ]
                    {
                        roots[[UInt8].init(name.utf8)] = index
                    }
                    // whitelist standard library modules 
                    whitelist.formUnion(biome.packages[index].modules)
                }
            }
            self.roots      = roots
            self.trunks     = .init(uniqueKeysWithValues: biome.modules.indices.map 
            {
                (biome.trunk(namespace: $0), $0)
            })
            self.greens     = [[]: 0]
            self.routes     = [:]
            self.overloads  = [:]
            self.greenlist  = [ ]
            self.whitelist  = whitelist
            
            for index:Int in biome.packages.indices
            {
                self.publish(packageSearchIndex: index, from: biome)
                self.publish(package: index, from: biome)
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
        func register(green key:[UInt8]) -> UInt 
        {
            var counter:UInt = .init(self.greens.count)
            self.greens.merge(CollectionOfOne<([UInt8], UInt)>.init((key, counter))) 
            { 
                (current:UInt, _:UInt) in 
                counter = current 
                return current 
            }
            return counter
        }
        
        mutating 
        func publish(article:Int, namespace:Int, stem:[[UInt8]], leaf:[UInt8])
        {
            self.publish(.article(article), 
                disambiguated: .article(namespace, 
                    stem: self.register(green: URI.concatenate(normalized: stem)),
                    leaf: self.register(green: leaf)))
        }
        
        private mutating 
        func publish(packageSearchIndex package:Int, from biome:Biome) 
        {
            self.publish(.packageSearchIndex(package), 
                disambiguated: .package(package, 
                stem:   self.register(green: URI.concatenate(normalized: biome.stem(packageSearchIndex: package))), 
                leaf:   self.register(green: biome.leaf(packageSearchIndex: package))))
        }
        private mutating 
        func publish(package:Int, from biome:Biome) 
        {
            self.publish(.package(package), disambiguated: 
                .package(package, stem: 0, leaf: 0))
        }
        private mutating 
        func publish(module:Int, from biome:Biome) 
        {
            self.publish(.module(module), disambiguated: 
                .namespaced(module, stem: 0, leaf: 0, overload: nil))
        }
        private mutating 
        func publish(witness:Int, victim:Int?, from biome:Biome) 
        {
            var selector:URI.Resolved, 
                amount:URI.Overloading? = nil
            if let namespace:Int = biome.symbols[victim ?? witness].namespace
            {
                let normalized:(stem:[[UInt8]], leaf:[UInt8]) = biome.stem(witness: witness, victim: victim)
                let stem:UInt   = self.register(green: URI.concatenate(normalized: normalized.stem))
                let leaf:UInt   = self.register(green: normalized.leaf)
                // greenlist operator leaves so they can recieve permanent redirects 
                // instead of temporary redirects 
                if case .operator = biome.symbols[witness].kind 
                {
                    self.greenlist.insert(leaf)
                }
                selector = .namespaced(namespace, stem: stem, leaf: leaf, overload: nil)
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
        func resolve(base:URI.Base, path:URI.Path, overload witness:Int?) -> (index:Index, assigned:Bool)? 
        {
            var components:Array<[UInt8]>.Iterator  = path.stem.makeIterator()
            guard let first:[UInt8]     = components.next()
            else 
            {
                return nil
            }
            guard let root:Int          = self.roots[first]
            else 
            {
                if  let trunk:Int       = self.trunks[first], 
                    let (index, assigned):(Index, assigned:Bool) = self.resolve(base: base, 
                        namespace: trunk, 
                        stem: path.stem.dropFirst(), 
                        leaf: path.leaf, 
                        overload: witness)
                {
                    // only allow whitelisted modules to be referenced without a package prefix
                    return (index, assigned ? self.whitelist.contains(trunk) : false)
                }
                else 
                {
                    return nil
                }
            }
            if  let second:[UInt8]  = components.next(),
                let trunk:Int       = self.trunks[second]
            {
                return self.resolve(base: base, 
                    namespace: trunk, 
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
        func resolve(base:URI.Base, namespace:Int, stem:ArraySlice<[UInt8]>, leaf:[UInt8], overload:Int?) 
            -> (index:Index, assigned:Bool)?
        {
            switch (base, overload) 
            {
            case (.biome, _):   
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
                // only allow greenlisted leaves (currently, operators) to recieve a 
                // permanent redirect
                if  self.greenlist.contains(leafKey),
                    let index:Index     = self.routes[fallback]
                {
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
            case (.learn, _?):  
                return nil
            case (.learn, nil):  
                if  let stemKey:UInt    = self.greens[URI.concatenate(normalized: stem)],
                    let leafKey:UInt    = self.greens[leaf], 
                    let index:Index     = self.routes[.article(namespace, stem: stemKey, leaf: leafKey)]
                {
                    return (index, true)
                }
                else 
                {
                    return nil
                }
            }
        }
        
        // helpers
        // FIXME: these are dropping the links if resolution fails!!!
        // we should show a reasonable fallback instead...
        func resolve(article:ArticleContent<UnresolvedLink>, context:UnresolvedLinkContext) -> ArticleContent<ResolvedLink> 
        {
            article.compactMapAnchors
            {
                // since symbols can always be referenced with a symbol link, 
                // prefer article resolutions over symbol resolutions
                (try? self.resolve(base: .learn, link: $0, context: context)) ??
                (try? self.resolve(base: .biome, link: $0, context: context))
            }
        }
        
        func resolve(base:URI.Base, link:UnresolvedLink, context:UnresolvedLinkContext) throws -> ResolvedLink 
        {
            let index:Index?
            switch link
            {
            case .preresolved(let resolved): 
                return resolved
            case .docc(doc: let stem, let suffix):
                index = self.resolveDocC(base: base, stem: stem, suffix: suffix, context: context)
            }
            switch index 
            {
            case nil, .package?, .packageSearchIndex?: 
                throw Documentation.ArticleError.undefinedSymbolReference(link)
            case .ambiguous?:
                throw Documentation.ArticleError.ambiguousSymbolReference(link)
            case .article(let index)?: 
                return .article(index)
            case .module(let index)?: 
                return .module(index)
            case .symbol(let witness, victim: let victim)?: 
                return .symbol(witness, victim: victim)
            }
        }
        private 
        func resolveDocC(base:URI.Base, stem:[[UInt8]], suffix:UnresolvedLink.Disambiguator.DocC?, 
            context:UnresolvedLinkContext) 
            -> Index?
        {
            let capitalized:Bool
            let lowercased:Bool
            if case .learn = base 
            {
                // never do leaf transformations for article URIs
                capitalized = true
                lowercased = false
            }
            else if case .kind(let kind)? = suffix 
            {
                capitalized = kind.capitalized
                lowercased = !kind.capitalized
            }
            else 
            {
                // we don’t know if this docc link is capitalized or not
                capitalized = true
                lowercased  = true
            }
            //  assume link is *absolute*, contains module prefix. 
            //  check this *first*, so that we can reference a module like 
            //  `JSON` as `JSON`, and its type of the same name as `JSON.JSON`.
            if  case context.namespace??    = stem.first.map({ self.trunks[$0] })
            {
                let stem:ArraySlice<[UInt8]> = stem.dropFirst()
                if  capitalized, 
                    case (let index, _)? = self.resolve(base: base, 
                        namespace: context.namespace, 
                        stem: stem, 
                        leaf: [], 
                        overload: nil)
                {
                    return index
                }
                if  lowercased, let leaf:[UInt8] = stem.last,
                    case (let index, _)? = self.resolve(base: base, 
                        namespace: context.namespace, 
                        stem: stem.dropFirst(), 
                        leaf: leaf, 
                        overload: nil)
                {
                    return index 
                }
            }
            //  assume link is *absolute*, does *not* contain module prefix
            if  capitalized, 
                case (let index, _)? = self.resolve(base: base, 
                    namespace: context.namespace, 
                    stem: stem[...], 
                    leaf: [], 
                    overload: nil)
            {
                return index
            }
            if  lowercased, let leaf:[UInt8] = stem.last,
                case (let index, _)? = self.resolve(base: base, 
                    namespace: context.namespace, 
                    stem: stem.dropFirst(), 
                    leaf: leaf, 
                    overload: nil)
            {
                return index
            }
            //  assume link is *relative*
            guard !context.scope.isEmpty 
            else 
            {
                return nil
            }
            let concatenated:[[UInt8]] = context.scope + stem
            if  capitalized, 
                case (let index, _)? = self.resolve(base: base, 
                    namespace: context.namespace, 
                    stem: concatenated[...], 
                    leaf: [], 
                    overload: nil)
            {
                return index
            }
            if  lowercased, let leaf:[UInt8] = concatenated.last,
                case (let index, _)? = self.resolve(base: base, 
                    namespace: context.namespace, 
                    stem: concatenated.dropFirst(), 
                    leaf: leaf, 
                    overload: nil)
            {
                return index
            }
            // failure 
            else 
            {
                return nil
            }
        }
    }
}
extension Biome 
{
    func stem(packageSearchIndex package:Int) -> [[UInt8]]
    {
        [[UInt8].init("search".utf8)]
    }
    func leaf(packageSearchIndex package:Int) -> [UInt8]
    {
        [UInt8].init("json".utf8)
    }
    func root(package:Int) -> [UInt8]
    {
        Documentation.URI.encode(component: self.packages[package].id.name.utf8)
    }
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
    func trunk(namespace module:Int) -> [UInt8]
    {
        Documentation.URI.encode(component: self.modules[module].id.title.utf8)
    }

    func stem(witness:Int, victim:Int?) -> (stem:[[UInt8]], leaf:[UInt8])
    {
        var stem:[[UInt8]]  = self.scope(witness: witness, victim: victim)
        let title:String    = self.symbols[witness].title
        if self.symbols[witness].kind.capitalized
        {
            stem.append(Documentation.URI.encode(component: title.utf8))
            return (stem: stem, leaf: [])
        }
        else 
        {
            return (stem: stem, leaf: Documentation.URI.encode(component: title.utf8))
        }
    }
    // this is *different* from `stem(witness:victim:)`
    func context(witness:Int, victim:Int?) -> [[UInt8]]
    {
        var context:[[UInt8]] = self.symbols[victim ?? witness].scope.map 
        { 
            Documentation.URI.encode(component: $0.utf8) 
        }
        switch self.symbols[witness].kind
        {
        case    .enum, .struct, .class, .actor, .protocol:
            // these create scopes, so resolve symbol links against them.
            context.append(Documentation.URI.encode(component: self.symbols[witness].title.utf8))
        
        case    .associatedtype, .typealias:
            // these are traditionally uppercased, but do not create scopes, 
            // so resolve symbol links against their *parents*.
            break
        case    .case, .initializer, .deinitializer, 
                .typeSubscript, .instanceSubscript, 
                .typeProperty, .instanceProperty, 
                .typeMethod, .instanceMethod, 
                .var, .func, .operator:
            break
        }
        return context
    }
    private 
    func scope(witness:Int, victim:Int?) -> [[UInt8]]
    {
        var stem:[[UInt8]] = self.symbols[victim ?? witness].scope.map 
        { 
            Documentation.URI.encode(component: $0.utf8) 
        }
        if let victim:Int = victim 
        {
            stem.append(Documentation.URI.encode(component: self.symbols[victim].title.utf8))
        }
        return stem 
    }
}

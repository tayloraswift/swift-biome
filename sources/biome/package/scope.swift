extension Module 
{
    //  the endpoints of a graph edge can reference symbols in either this 
    //  package or one of its dependencies. since imports are module-wise, and 
    //  not package-wise, it’s possible for multiple index dictionaries to 
    //  return matches, as long as only one of them belongs to an depended-upon module.
    //  
    //  it’s also possible to prefer a dictionary result in a foreign package over 
    //  a dictionary result in the local package, if the foreign package contains 
    //  a module that shadows one of the modules in the local package (as long 
    //  as the target itself does not also depend upon the shadowed local module.)
    struct Scope
    {
        private 
        var namespaces:[ID: Index], 
            filter:Set<Index>
        let culture:Index
        
        init(_ module:Module)
        {
            self.namespaces = [module.id: module.index]
            self.filter = [module.index]
            self.culture = module.index 
        }
        
        subscript(namespace:ID) -> Index?
        {
            _read 
            {
                yield self.namespaces[namespace]
            }
        }
        
        func contains(_ namespace:ID) -> Bool
        {
            self.namespaces.keys.contains(namespace)
        }
        func contains(_ namespace:Index) -> Bool
        {
            self.filter.contains(namespace)
        }
        
        mutating 
        func insert(_ module:Module)
        {
            self.namespaces[module.id] = module.index
            self.filter.insert(module.index)
        }
    }
}
extension Symbol 
{
    public
    struct Scope
    {
        public 
        struct ResolutionError:Error, Hashable 
        {
            var id:Symbol.ID 
            
            public 
            var description:String 
            {
                "could not resolve symbol '\(self.id.string)' (\(self.id.description))"
            }
        }
        
        var culture:Module.Index 
        {
            self.namespaces.culture
        }
        
        var namespaces:Module.Scope
        var lenses:[[Symbol.ID: Symbol.Index]]
        
        init(namespaces:Module.Scope)
        {
            self.namespaces = namespaces
            self.lenses = [] 
        }
        
        func index(of id:Symbol.ID) throws -> Symbol.Index 
        {
            if let index:Symbol.Index = self.find(id)
            {
                return index 
            }
            else 
            {
                throw ResolutionError.init(id: id)
            } 
        }
        func contains(_ id:Symbol.ID) -> Bool
        {
            for lens:[Symbol.ID: Symbol.Index] in self.lenses
            {
                if let index:Symbol.Index = lens[id], self.namespaces.contains(index.module)
                {
                    return true  
                }
            }
            return false
        }
        func find(_ id:Symbol.ID) -> Symbol.Index?
        {
            var match:Symbol.Index? = nil
            for lens:[Symbol.ID: Symbol.Index] in self.lenses
            {
                guard let index:Symbol.Index = lens[id], self.namespaces.contains(index.module)
                else 
                {
                    continue 
                }
                if case nil = match 
                {
                    match = index
                }
                else 
                {
                    // sanity check: ensure none of the remaining lenses contains 
                    // a colliding key 
                    fatalError("colliding symbol identifiers in search space")
                }
            }
            return match
        }
    }
}

struct LexicalScope
{
    var namespaces:Module.Scope
    var lenses:[LexicalLens]
    let keys:Route.Keys
    
    var culture:Module.Index 
    {
        self.namespaces.culture
    }
    
    init(namespaces:Module.Scope, 
        lenses:[LexicalLens], 
        keys:Route.Keys)
    {
        self.namespaces = namespaces
        self.lenses = lenses
        self.keys = keys 
    }
    
    func resolve<Path>(visible link:Link.Reference<Path>, 
        _ dereference:(Symbol.Index) throws -> Symbol) 
        rethrows -> Link.Resolution?
        where Path:BidirectionalCollection, Path.Element == Link.Component
    {
        try self.resolve(                   qualified: link, dereference) ?? 
            self.resolve(implicit: self.culture, full: link, dereference)
    }
    func resolve<Path>(qualified link:Link.Reference<Path>, 
        _ dereference:(Symbol.Index) throws -> Symbol) 
        rethrows -> Link.Resolution?
        where Path:BidirectionalCollection, Path.Element == Link.Component
    {
        // check if the first component refers to a module. it can be the same 
        // as its own culture, or one of its dependencies. 
        
        // ``modulename/typename.membername(_:)``
        if  let namespace:Module.ID = link.namespace, 
            let namespace:Module.Index = self.namespaces[namespace]
        {
            return try self.resolve(implicit: namespace, full: link.dropFirst(), dereference)
        }
        else 
        {
            return nil
        }
    }
    func resolve<Path>(implicit namespace:Module.Index, full link:Link.Reference<Path>, 
        _ dereference:(Symbol.Index) throws -> Symbol) 
        rethrows -> Link.Resolution?
        where Path:BidirectionalCollection, Path.Element == Link.Component
    {
        let path:[String] = link.path.compactMap(\.prefix)
        
        guard let last:String = path.last 
        else 
        {
            return .one(.module(namespace))
        }
        guard let route:Route = keys[namespace, path.dropLast(), last, link.orientation]
        else 
        {
            return nil
        }
        // results that match orientation should take precedence over 
        // results that do not match orientation.
        let disambiguation:Link.Disambiguation = link.disambiguation
        let exact:[Symbol.Group] = self.lenses.compactMap { $0[exactly: route] }
        if  let resolution:Link.Resolution = try disambiguation.filter(exact, 
            by: dereference, where: self.namespaces.contains(_:))
        {
            return resolution
        }
        guard let route:Route = route.outed
        else 
        {
            return nil
        }
        let redirects:[Symbol.Group] = self.lenses.compactMap { $0[exactly: route] }
        if  let resolution:Link.Resolution = try disambiguation.filter(redirects, 
            by: dereference, where: self.namespaces.contains(_:))
        {
            return resolution
        }
        else 
        {
            return nil
        }
    }
}
struct LexicalLens:Sendable 
{
    private 
    var groups:[Route: Symbol.Group]
    
    var count:Int 
    {
        self.groups.count
    }
    
    init()
    {
        self.groups = [:]
    }
    
    subscript(exactly route:Route) -> Symbol.Group?
    {
        self.groups[route] 
    }
    /* private 
    subscript(route:Route) -> Symbol.Group?
    {
        if let group:Symbol.Group = self.groups[route] 
        {
            return group
        }
        else if let route:Route = route.outed
        {
            return self.groups[route]
        }
        else 
        {
            return nil
        }
    } */
    
    mutating 
    func insert(natural:(symbol:Symbol.Index, route:Route)) 
    {
        self.groups[natural.route, default: .none].insert(.init(natural: natural.symbol))
    }
    mutating 
    func insert(perpetrator:Module.Index, 
        victim:(symbol:Symbol.Index, namespace:Module.Index, path:Route.Stem), 
        features:[(base:Symbol.Index, leaf:Route.Leaf)]) 
    {
        for (feature, leaf):(Symbol.Index, Route.Leaf) in features 
        {
            let route:Route = .init(victim.namespace, victim.path, leaf)
            let crime:Crime = .init(victim: victim.symbol, feature: feature, 
                culture: perpetrator)
            self.groups[route, default: .none].insert(crime)
        }
    }
    mutating 
    func merge(_ other:Self)
    {
        self.groups.merge(other.groups) { $0.union($1) }
    }
    /* 
    func select<Path>(_ namespace:Module.Index, _ nest:[String] = [], _ link:Link.Reference<Path>, 
        keys:Route.Keys) 
        throws -> Link.ResolutionGroup?
        where Path:BidirectionalCollection, Path.Element == Link.Component
    {
        let path:[String] = nest.isEmpty ? 
            link.path.compactMap(\.prefix) : nest + link.path.compactMap(\.prefix)
        
        guard   let last:String = path.last 
        else 
        {
            return .one(.module(namespace))
        }
        guard   let route:Route = keys[namespace, path.dropLast(), last, link.orientation], 
                let group:Symbol.Group = self[route]
        else 
        {
            return nil
        }
        switch group 
        {
        case .none: 
            fatalError("unreachable")
        case .one(let pair): 
            return .one(.symbol(pair))
        case .many(let pairs):
            return .many(pairs, link.disambiguation)
        }
    } */
}

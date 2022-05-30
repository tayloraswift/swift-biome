struct Lexicon
{
    struct Lens:Sendable 
    {
        let groups:[Route: Symbol.Group]
        let learn:[Route: Article.Index]
                
        subscript(group route:Route) -> Symbol.Group?
        {
            self.groups[route] 
        }
        
        // single-lens resolution
        func resolve(_ route:Route, disambiguation:Link.Disambiguation, 
            _ dereference:(Symbol.Index) throws -> Symbol) 
            rethrows -> Link.Resolution?
        {
            // results that match orientation should take precedence over 
            // results that do not match orientation.
            if  let group:Symbol.Group = self[group: route],
                let resolution:Link.Resolution = 
                try disambiguation.filter(group, by: dereference, where: { _ in true })
            {
                return resolution
            }
            if  let route:Route = route.outed, 
                let group:Symbol.Group = self[group: route],
                let resolution:Link.Resolution = 
                try disambiguation.filter(group, by: dereference, where: { _ in true })
            {
                return resolution
            }
            else 
            {
                return nil
            }
        }
    }
    
    var namespaces:Module.Scope
    var lenses:[Lens]
    let keys:Route.Keys
    
    var culture:Module.Index 
    {
        self.namespaces.culture
    }
    
    init(keys:Route.Keys, namespaces:Module.Scope, lenses:[Lens])
    {
        self.namespaces = namespaces
        self.lenses = lenses
        self.keys = keys 
    }
    
    func resolve<Modules>(imports modules:Modules) -> [Module.Index]
        where Modules:Sequence, Modules.Element == Module.ID
    {
        modules.compactMap { self.namespaces[$0] }
    }
    
    func resolve<Tail>(
        visible link:Link.Reference<Tail>, 
        imports:Set<Module.Index>, 
        nest:Symbol.Nest?, 
        _ dereference:(Symbol.Index) throws -> Symbol) 
        rethrows -> Link.Resolution?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        if  let qualified:Link.Resolution = 
            try self.resolve(qualified: link, dereference)
        {
            return qualified
        }
        if  let nest:Symbol.Nest = nest, 
            self.culture == nest.namespace || imports.contains(nest.namespace), 
            let relative:Link.Resolution = 
            try self.resolve(nest.namespace, nest.prefix, link, dereference)
        {
            return relative
        }
        if  let absolute:Link.Resolution = 
            try self.resolve(self.culture, [], link, dereference) 
        {
            return absolute
        }
        var imported:Link.Resolution? = nil 
        for namespace:Module.Index in imports where namespace != self.culture 
        {
            guard let absolute:Link.Resolution = 
                try self.resolve(namespace, [], link, dereference) 
            else 
            {
                continue 
            }
            if case nil = imported 
            {
                imported = absolute
            }
            else 
            {
                // name collision
                return nil 
            }
        }
        return imported 
    }
    func resolve<Tail>(visible link:Link.Reference<Tail>, 
        _ dereference:(Symbol.Index) throws -> Symbol) 
        rethrows -> Link.Resolution?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        try self.resolve(       qualified: link, dereference) ?? 
            self.resolve(self.culture, [], link, dereference)
    }
    func resolve<Tail>(qualified link:Link.Reference<Tail>, 
        _ dereference:(Symbol.Index) throws -> Symbol) 
        rethrows -> Link.Resolution?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        // check if the first component refers to a module. it can be the same 
        // as its own culture, or one of its dependencies. 
        
        // ``modulename/typename.membername(_:)``
        if  let namespace:Module.ID = link.namespace, 
            let namespace:Module.Index = self.namespaces[namespace]
        {
            return try self.resolve(namespace, [], link.dropFirst(), dereference)
        }
        else 
        {
            return nil
        }
    }
    func resolve<Tail>(_ namespace:Module.Index, _ prefix:[String], 
        _ link:Link.Reference<Tail>, 
        _ dereference:(Symbol.Index) throws -> Symbol) 
        rethrows -> Link.Resolution?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        let suffix:[String] = link.path.compactMap(\.prefix)
        guard let path:Path = prefix.isEmpty ? 
            .init(suffix) : .init([prefix, suffix].joined())
        else 
        {
            return .one(.module(namespace))
        }
        guard let route:Route = keys[namespace, path, link.orientation]
        else 
        {
            return nil
        }
        return try self.resolve(route, disambiguation: link.disambiguation, dereference)
    }
    func resolve(_ route:Route, disambiguation:Link.Disambiguation, 
        _ dereference:(Symbol.Index) throws -> Symbol) 
        rethrows -> Link.Resolution?
    {
        // results that match orientation should take precedence over 
        // results that do not match orientation.
        let exact:[Symbol.Group] = self.lenses.compactMap { $0[group: route] }
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
        let redirects:[Symbol.Group] = self.lenses.compactMap { $0[group: route] }
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

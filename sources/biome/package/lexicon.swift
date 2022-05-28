struct Lexicon
{
    struct Lens:Sendable 
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
    
    func resolve<Path>(visible link:Link.Reference<Path>, 
        imports:Set<Module.Index>, 
        context:Symbol, 
        _ dereference:(Symbol.Index) throws -> Symbol) 
        rethrows -> Link.Resolution?
        where Path:BidirectionalCollection, Path.Element == Link.Component
    {
        if  let qualified:Link.Resolution = 
            try self.resolve(qualified: link, dereference)
        {
            return qualified
        }
        if !context.nest.isEmpty, 
            self.culture == context.namespace || imports.contains(context.namespace), 
            let relative:Link.Resolution = 
            try self.resolve(context.namespace, context.nest, link, dereference)
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
    func resolve<Path>(visible link:Link.Reference<Path>, 
        _ dereference:(Symbol.Index) throws -> Symbol) 
        rethrows -> Link.Resolution?
        where Path:BidirectionalCollection, Path.Element == Link.Component
    {
        try self.resolve(       qualified: link, dereference) ?? 
            self.resolve(self.culture, [], link, dereference)
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
            return try self.resolve(namespace, [], link.dropFirst(), dereference)
        }
        else 
        {
            return nil
        }
    }
    func resolve<Path>(_ namespace:Module.Index, _ nest:[String], _ link:Link.Reference<Path>, 
        _ dereference:(Symbol.Index) throws -> Symbol) 
        rethrows -> Link.Resolution?
        where Path:BidirectionalCollection, Path.Element == Link.Component
    {
        let path:[String] = nest.isEmpty ? 
                   link.path.compactMap(\.prefix) : 
            nest + link.path.compactMap(\.prefix)
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

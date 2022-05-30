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
    
    func resolve<Path>(
        visible link:Link.Reference<Path>, 
        imports:Set<Module.Index>, 
        nest:Symbol.Nest?, 
        _ dereference:(Symbol.Index) throws -> Symbol) 
        rethrows -> Link.Resolution?
        where Path:BidirectionalCollection, Path.Element == Link.Component
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
    func resolve<Path>(_ namespace:Module.Index, _ prefix:[String], _ link:Link.Reference<Path>, 
        _ dereference:(Symbol.Index) throws -> Symbol) 
        rethrows -> Link.Resolution?
        where Path:BidirectionalCollection, Path.Element == Link.Component
    {
        let path:[String] = prefix.isEmpty ? 
                     link.path.compactMap(\.prefix) : 
            prefix + link.path.compactMap(\.prefix)
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

extension Lexicon 
{
    func resolve(expression:String, imports:Set<Module.Index>, nest:Symbol.Nest?, 
        _ dereference:(Symbol.Index) throws -> Symbol) 
        rethrows -> Link
    {
        // must attempt to parse absolute first, otherwise 
        // '/foo' will parse to ["", "foo"]
        if      let _:Link.Expression = try? .init(absolute: expression)
        {
            print("global", expression)
        }
        else if let link:Link.Expression = try? .init(relative: expression)
        {
            switch try self.resolve(visible: link.reference, 
                imports: imports, nest: nest, dereference)
            {
            case nil:
                print("FAILURE", expression)
                print("note: location is \(nest as Any)")
                
            case .one(.composite(let composite))?:
                /* if let victim:Symbol.Index = composite.victim 
                {
                    print("SUCCESS", expression, "->", try dereference(composite.base), 
                        "for", try dereference(victim))
                }
                else 
                {
                    print("SUCCESS", expression, "->", try dereference(composite.base))
                } */
                return .target(.composite(composite))
            
            case .one(let target)?: 
                //print("SUCCESS", expression, "-> (unavailable)")
                return .target(target)
            
            case .many(let possibilities)?: 
                print("AMBIGUOUS", expression)
                for (i, possibility):(Int, Link.Target) in possibilities.enumerated()
                {
                    switch possibility 
                    {
                    case .composite(let composite):
                        if let victim:Symbol.Index = composite.victim 
                        {
                            print("\(i).", try dereference(composite.base), 
                                "for", try dereference(victim))
                        }
                        else 
                        {
                            print("\(i).", try dereference(composite.base))
                        }
                    default: 
                        print("\(i). (unavailable)")
                    }
                }
                print("note: location is \(nest as Any)")
            }
        }
        else 
        {
            print("unknown", expression)
        }
        return .fallback(expression)
    }
}

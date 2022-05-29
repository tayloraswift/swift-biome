extension Route 
{
    struct Keys 
    {
        private 
        var counter:Stem
        private
        var table:[String: Stem]
        
        init() 
        {
            self.counter = .init()
            self.table = [:]
        }
        
        private static 
        func subpath<S>(_ component:S) -> String 
            where S:StringProtocol 
        {
            component.lowercased()
        }
        private static 
        func subpath<S>(_ components:S) -> String 
            where S:Sequence, S.Element:StringProtocol 
        {
            components.map { $0.lowercased() }.joined(separator: "\u{0}")
        }
        
        private 
        subscript(subpath:String) -> Stem? 
        {
            self.table[subpath]
        }
        
        private 
        subscript<Component>(leaf component:Component) -> Stem? 
            where Component:StringProtocol 
        {
            self.table[Self.subpath(component)]
        }        
        private 
        subscript<Path>(stem components:Path) -> Stem? 
            where Path:Sequence, Path.Element:StringProtocol 
        {
            self.table[Self.subpath(components)]
        }
        
        subscript<Prefix, Last>(
            namespace:Module.Index, 
            prefix:Prefix, 
            last:Last, orientation:Orientation) -> Route? 
            where Prefix:Sequence, Prefix.Element:StringProtocol, Last:StringProtocol
        {
            guard   let stem:Stem = self[stem: prefix],
                    let leaf:Stem = self[leaf: last]
            else 
            {
                return nil
            }
            return .init(namespace, stem, leaf, orientation: orientation)
        }
        
        private mutating 
        func register(_ string:String) -> Stem 
        {
            if let stem:Stem = self.table[string]
            {
                return stem 
            }
            else 
            {
                self.table[string] = self.counter.increment()
                return self.counter
            }
        }
        
        mutating 
        func register(complete symbol:Symbol) -> Stem 
        {
            symbol.nest.isEmpty ? symbol.route.leaf.stem : self.register(components: symbol.nest + [symbol.name])
        }
        mutating 
        func register<S>(components:S) -> Stem 
            where S:Sequence, S.Element:StringProtocol 
        {
            self.register(Self.subpath(components))
        }
        mutating 
        func register<S>(component:S) -> Stem 
            where S:StringProtocol 
        {
            self.register(Self.subpath(component))
        }
        
        mutating 
        func groups(_ ideologies:[Module.Index: Module.Beliefs], 
            _ dereference:(Symbol.Index) throws -> Symbol)
            rethrows -> Symbol.Groups
        {
            var groups:Symbol.Groups = .init()
            for (culture, beliefs):(Module.Index, Module.Beliefs) in ideologies 
            {
                for (host, relationships):(Symbol.Index, Symbol.Relationships) in beliefs.facts
                {
                    let symbol:Symbol = try dereference(host)
                    
                    groups.insert(natural: (host, symbol.route))
                    
                    let features:[(perpetrator:Module.Index?, features:[Symbol.Index])] = 
                        relationships.features(assuming: symbol.color)
                    if  features.isEmpty
                    {
                        continue 
                    }
                    // don’t register the complete host path unless we have at 
                    // least one feature!
                    let path:Stem = self.register(complete: symbol)
                    for (perpetrator, features):(Module.Index?, [Symbol.Index]) in features 
                    {
                        groups.insert(perpetrator: perpetrator ?? culture, 
                            victim: (host, symbol.namespace, path), 
                            features: try features.map 
                            { 
                                ($0, try dereference($0).route.leaf) 
                            })
                    }
                }
                for (host, traits):(Symbol.Index, [Symbol.Trait]) in beliefs.opinions.values.joined()
                {
                    let features:[Symbol.Index] = traits.compactMap(\.feature) 
                    if !features.isEmpty
                    {
                        let symbol:Symbol = try dereference(host)
                        let path:Stem = self.register(complete: symbol)
                        groups.insert(perpetrator: culture, 
                            victim: (host, symbol.namespace, path), 
                            features: try features.map 
                            {
                                ($0, try dereference($0).route.leaf)
                            })
                    }
                }
            }
            return groups
        }
    }
}

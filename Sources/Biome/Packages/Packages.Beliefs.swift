import SymbolGraphs

extension Packages 
{
    struct Beliefs 
    {
        private(set) 
        var facts:[Symbol.Index: Symbol.Facts] 
        private 
        var local:[Symbol.Diacritic: Symbol.Traits] 
        private(set) 
        var opinions:[Symbol.Diacritic: Symbol.Traits] 

        init()
        {
            self.facts = [:]
            self.local = [:]
            self.opinions = [:]
        }

        mutating 
        func generate(statements:[Symbol.Statement], 
            subjects:[Symbol.Index], 
            culture:Module.Index)
        {
            var traits:[Symbol.Index: [Symbol.Trait<Symbol.Index>]] = [:]
            var roles:[Symbol.Index: [Symbol.Role<Symbol.Index>]] = [:]
            for (subject, predicate):Symbol.Statement in statements 
            {
                switch (culture == subject.module, predicate)
                {
                case (false,  .is(let role)):
                    throw PoliticalError.module(self[culture].id, says: self[subject].id, 
                        is: role.map { self[$0].id })
                case (false, .has(let trait)):
                    traits  [subject, default: []].append(trait)
                case (true,  .has(let trait)):
                    traits  [subject, default: []].append(trait)
                case (true,   .is(let role)):
                    roles   [subject, default: []].append(role)
                }
            }
            for symbol:Symbol.Index in subjects 
            {
                do 
                {
                    self.facts[symbol] = try .init(
                        traits: traits.removeValue(forKey: symbol) ?? [],
                        roles: roles.removeValue(forKey: symbol) ?? [], 
                        as: self[symbol].community)
                }
                catch let error as Symbol.PoliticalError<Symbol.Index>
                {
                    throw PoliticalError.symbol(self[symbol].id, error.map { self[$0].id })
                }
            }
            for (symbol, traits):(Symbol.Index, [Symbol.Trait<Symbol.Index>]) in traits 
            {
                let diacritic:Symbol.Diacritic = .init(host: symbol, culture: culture)
                let traits:Symbol.Traits = .init(traits, as: self[symbol].community)
                if symbol.module.package == culture.package 
                {
                    self.local[diacritic] = traits 
                }
                else 
                {
                    self.opinions[diacritic] = traits
                }
            }
        }
        mutating 
        func polarize() 
        {
            for (diacritic, traits):(Symbol.Diacritic, Symbol.Traits) in self.local 
            {
                if  let index:Dictionary<Symbol.Index, Symbol.Facts>.Index = 
                    self.facts.index(forKey: diacritic.host)
                {
                    assert(diacritic.host.module != diacritic.culture)
                    self.facts.values[index].predicates.updateAcceptedTraits(traits, 
                        culture: diacritic.culture)
                }
            }
            self.local = [:]
        }
    }
    mutating 
    func updateImplicitSymbols(in cultures:[Module.Index], 
        indices:[[Symbol.Index?]],
        graphs:[SymbolGraph])
        throws
    {
        // compute relationships
        var beliefs:Beliefs = .init() 
        for (culture, (graph, indices)):(Module.Index, (SymbolGraph, [Symbol.Index?])) in 
            zip(cultures, zip(graphs, indices))
        {
            // the `prefix` excludes symbols that were once in the current package, 
            // but for whatever reason were left out of the current version of the 
            // current package.
            // the `compactMap` excludes symbols that are not native to the current 
            // module. this happens sometimes due to member inference.
            try beliefs.generate(statements: try self.generateRhetoric(from: graph, indices: indices), 
                subjects: indices.prefix(graphs.vertices.count).compactMap 
                {
                    $0.flatMap { $0.module == culture ? $0 : nil }
                }, 
                culture: culture)
        }
        
        beliefs.polarize()

        
        // none of these methods read from the keyframe buffers, so we can order 
        // the method calls any way we like...
        self[index].assignShapes(beliefs.facts)
        self[index].updateFacts(beliefs.facts)
        self[index].updateOpinions(beliefs.opinions)
        self.updateCompositeGroups(in: index, beliefs: beliefs)
        
        // pollinate opinions 
        let current:Version = self[index].versions.latest
        for diacritic:Symbol.Diacritic in beliefs.opinions.keys 
        {
            let pin:Module.Pin = .init(culture: diacritic.culture, version: current)
            self[diacritic.host.module.package].pollinate(local: diacritic.host, from: pin)
        }
    }
    
    private 
    func generateRhetoric(from graph:SymbolGraph, indices:[Symbol.Index?])
        throws -> [Symbol.Statement]
    {
        var errors:[Symbol.LookupError] = []
        // if we have `n` edges, we will get between `n` and `2n` statements
        var statements:[Symbol.Statement] = []
            statements.reserveCapacity(graph.edges.count)
        for edge:SymbolGraph.Edge<Int> in graph.edges
        {
            let indexed:SymbolGraph.Edge<(Community, Symbol.Index)>
            do 
            {
                indexed = try edge.map 
                {
                    if let index:Symbol.Index = indices[$0]
                    {
                        return (self[index].community, index) 
                    }
                    else 
                    {
                        throw Symbol.LookupError.unknownID(graph.identifiers[$0])
                    }
                }
            } 
            catch let error as Symbol.LookupError 
            {
                errors.append(error)
                continue
            }
            do 
            {
                switch try indexed.generateStatements()
                {
                case (let source?,  let target):
                    statements.append(source)
                    statements.append(target)
                case (nil,          let target):
                    statements.append(target)
                }
            }
            catch let error as Symbol.PoliticalError<(Community, Symbol.Index)>
            {
                throw PoliticalError.symbol(edge.source, error.map { self[$0].id })
            }
        }

        if !errors.isEmpty 
        {
            print("warning: dropped \(errors.count) edges from '\(graph.id)'")
        }

        return statements
    }
}
extension SymbolGraph.Edge where Source == (Community, Symbol.Index)
{
    func statements() throws -> (source:Symbol.Statement?, target:Symbol.Statement)
    {
        switch (self.source, self.target) 
        {
        case    ((.callable(_),     let source), is: .feature(of: (.concretetype(_), let target))):
            return
                (
                    nil,
                    (target, .has(.feature(source)))
                )
        
        case    ((.concretetype(_), let source), is: .member(of: (.concretetype(_), let target))), 
                ((.typealias,       let source), is: .member(of: (.concretetype(_), let target))), 
                ((.callable(_),     let source), is: .member(of: (.concretetype(_), let target))), 
                ((.concretetype(_), let source), is: .member(of: (.protocol, let target))),
                ((.typealias,       let source), is: .member(of: (.protocol, let target))),
                ((.callable(_),     let source), is: .member(of: (.protocol, let target))):
            return 
                (
                    (source,  .is(.member(of: target))), 
                    (target, .has(.member(    source)))
                )
        
        case    ((.concretetype(_), let source), is: .conformer(of: (.protocol, let target))):
            return 
                (
                    (source, .has(.conformance(.init(target, where: constraints)))), 
                    (target, .has(  .conformer(.init(source, where: constraints))))
                )
         
        case    ((.protocol,        let source), is: .conformer(of: (.protocol, let target))):
            return 
                (
                    (source,  .is(.refinement(of: target))), 
                    (target, .has(.refinement(    source)))
                ) 
        
        case    ((.class,           let source), is: .subclass(of: (.class, let target))):
            return 
                (
                    (source,  .is(.subclass(of: target))), 
                    (target, .has(.subclass(    source)))
                ) 
         
        case    ((.associatedtype,  let source), is: .override(of: (.associatedtype, let target))),
                ((.callable(_),     let source), is: .override(of: (.callable,       let target))):
            return 
                (
                    (source,  .is(.override(of: target))), 
                    (target, .has(.override(    source)))
                ) 
         
        case    ((.associatedtype,  let source), is:         .requirement(of: (.protocol, let target))),
                ((.callable(_),     let source), is:         .requirement(of: (.protocol, let target))),
                ((.associatedtype,  let source), is: .optionalRequirement(of: (.protocol, let target))),
                ((.callable(_),     let source), is: .optionalRequirement(of: (.protocol, let target))):
            return 
                (
                    (source,  .is(.requirement(of: target))), 
                    (target,  .is(  .interface(of: source)))
                ) 
         
        case    ((.callable(_),     let source), is: .defaultImplementation(of: (.callable(_), let target))):
            return 
                (
                    (source,  .is(.implementation(of: target))), 
                    (target, .has(.implementation(    source)))
                ) 
        
        default:
            throw Symbol.PoliticalError.invalidEdge(self)
        }
    }
}

extension Packages 
{
    mutating 
    func updateCompositeGroups(in index:Package.Index, beliefs:Beliefs)
    {
        for (host, facts):(Symbol.Index, Symbol.Facts) in beliefs.facts
        {
            assert(host.module.package == index)
            
            let symbol:Symbol = self[host]
            
            self[index].groups.insert(natural: host, at: symbol.route)
            
            guard let path:Stem = symbol.kind.path
            else 
            {
                continue 
            }
            for (culture, features):(Module.Index?, Set<Symbol.Index>) in 
                facts.predicates.featuresAssumingConcreteType()
            {
                self[index].groups.insert(
                    diacritic: .init(host: host, culture: culture ?? host.module), 
                    features: features.map { ($0, self[$0].route.leaf) }, 
                    under: (symbol.namespace, path))
            }
        }
        for (diacritic, traits):(Symbol.Diacritic, Symbol.Traits) in beliefs.opinions
        {
            assert(diacritic.host.module.package != index)
            
            let symbol:Symbol = self[diacritic.host]
            
            guard let path:Stem = symbol.kind.path
            else 
            {
                // can have external traits that do not have to do with features
                continue 
            }
            if !traits.features.isEmpty
            {
                self[index].groups.insert(diacritic: diacritic, 
                    features: traits.features.map { ($0, self[$0].route.leaf) }, 
                    under: (symbol.namespace, path))
            }
        }
        
        print("(\(self[index].id)) found \(self[index].groups._count) addressable endpoints")
    }
}

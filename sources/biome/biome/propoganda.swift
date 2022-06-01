extension Module 
{
    struct Beliefs 
    {
        var facts:[Symbol.Index: Symbol.Relationships]
        var opinions:[Package.Index: [Symbol.Index: [Symbol.Trait]]]
        
        init()
        {
            self.opinions = [:]
            self.facts = [:]
        }
    }
}

extension Ecosystem 
{
    typealias Opinions = [Package.Index: [Symbol.Index: [Symbol.Trait]]]
    
    mutating 
    func updateImplicitSymbols<Symbols>(in index:Package.Index, 
        fromExplicit symbols:[Symbols],
        graphs:[Module.Graph],
        scopes:[Symbol.Scope])
        throws -> [Symbol.Index: Symbol.Index]
        where Symbols:Sequence, Symbols.Element == Symbol.Index
    {
        let (speeches, hints):([[Symbol.Statement]], [Symbol.Index: Symbol.Index]) = 
            try self.generateRhetoric(graphs: graphs, scopes: scopes)
        // compute relationships
        let ideology:[Module.Index: Module.Beliefs] = 
            try self[index].generateIdeology(for: scopes.map(\.culture), 
                from: speeches, 
                about: symbols)
        
        self.updateFeatures(in: index, ideology: ideology)
        // ``updateFeatures(in:ideology:)`` doesn’t read from the keyframe buffers, 
        // so it’s okay to call it before ``updateRelationships(ideology:)``.
        let pin:Package.Pin = self[index].pin 
        for (culture, stereotype):(Package.Index, [Symbol.Index: [Symbol.Trait]]) in 
            self[index].updateRelationships(ideology: ideology)
        {
            self[culture].assign(stereotype: stereotype, from: pin)
        }
        return hints
    }
    
    private 
    func generateRhetoric(graphs:[Module.Graph], scopes:[Symbol.Scope])
        throws -> (speeches:[[Symbol.Statement]], hints:[Symbol.Index: Symbol.Index])
    {
        var uptree:[Symbol.Index: Symbol.Index] = [:]
        var speeches:[[Symbol.Statement]] = [] 
            speeches.reserveCapacity(scopes.count)
        for (graph, scope):(Module.Graph, Symbol.Scope) in zip(graphs, scopes)
        {
            // if we have `n` edges, we will get between `n` and `2n` statements
            var statements:[Symbol.Statement] = []
                statements.reserveCapacity(graph.edges.reduce(0) { $0 + $1.count })
            for edge:Edge in graph.edges.joined()
            {
                var constraints:Set<Generic.Constraint<Symbol.Index>> = []
                for constraint:Generic.Constraint<Symbol.ID> in edge.constraints
                {
                    constraints.insert(try constraint.map(scope.index(of:)))
                }
                let (source, target):(Symbol.Index, Symbol.Index) = 
                (
                    try scope.index(of: edge.source),
                    try scope.index(of: edge.target)
                )
                
                switch try self.generateStatements(
                    when: source, is: edge.kind, of: target, where: constraints)
                {
                case (let source?,  let target):
                    statements.append(source)
                    statements.append(target)
                case (nil,          let target):
                    statements.append(target)
                }
                
                // don’t care about hints for symbols in other packages
                if  source.module.package == scope.culture.package, 
                    let origin:Symbol.ID = edge.origin, 
                // this fails quite frequently. we don’t have a great solution for this.
                    let origin:Symbol.Index = try? scope.index(of: origin), origin != source
                {
                    uptree[source] = origin
                }
            }
            speeches.append(statements)
        }
        
        // flatten the uptree, in O(n). every item in the dictionary will be 
        // visited at most twice.
        for index:Dictionary<Symbol.Index, Symbol.Index>.Index in uptree.indices 
        {
            var crumbs:Set<Dictionary<Symbol.Index, Symbol.Index>.Index> = []
            var current:Dictionary<Symbol.Index, Symbol.Index>.Index = index
            while let union:Dictionary<Symbol.Index, Symbol.Index>.Index = 
                uptree.index(forKey: uptree.values[current])
            {
                assert(current != union)
                
                crumbs.update(with: current)
                current = union
                
                if crumbs.contains(union)
                {
                    fatalError("detected cycle in doccomment uptree")
                }
            }
            for crumb:Dictionary<Symbol.Index, Symbol.Index>.Index in crumbs 
            {
                uptree.values[crumb] = uptree.values[current]
            }
        }
        return (speeches, uptree)
    }
    
    private 
    func generateStatements(
        when source:Symbol.Index, is label:Edge.Kind, of target:Symbol.Index, 
        where constraints:Set<Generic.Constraint<Symbol.Index>>)
        throws -> (source:Symbol.Statement?, target:Symbol.Statement)
    {
        switch  
        (
                self[source].color,
            is: label,
            of: self[target].color,
            unconditional: constraints.isEmpty
        ) 
        {
        case    (.callable(_),      is: .feature,               of: .concretetype(_),   unconditional: true):
            return
                (
                    nil,
                    (target, .has(.feature(source)))
                )
        
        case    (.concretetype(_),  is: .member,                of: .concretetype(_),   unconditional: true), 
                (.typealias,        is: .member,                of: .concretetype(_),   unconditional: true), 
                (.callable(_),      is: .member,                of: .concretetype(_),   unconditional: true), 
                (.concretetype(_),  is: .member,                of: .protocol,          unconditional: true),
                (.typealias,        is: .member,                of: .protocol,          unconditional: true),
                (.callable(_),      is: .member,                of: .protocol,          unconditional: true):
            return 
                (
                    (source,  .is(.member(of: target))), 
                    (target, .has(.member(    source)))
                )
        
        case    (.concretetype(_),  is: .conformer,             of: .protocol,          unconditional: _):
            return 
                (
                    (source, .has(.conformance(target, where: constraints))), 
                    (target, .has(  .conformer(source, where: constraints)))
                )
         
        case    (.protocol,         is: .conformer,             of: .protocol,          unconditional: true):
            return 
                (
                    (source,  .is(.refinement(of: target))), 
                    (target, .has(.refinement(    source)))
                ) 
        
        case    (.class,            is: .subclass,              of: .class,             unconditional: true):
            return 
                (
                    (source,  .is(.subclass(of: target))), 
                    (target, .has(.subclass(    source)))
                ) 
         
        case    (.associatedtype,   is: .override,              of: .associatedtype,    unconditional: true),
                (.callable(_),      is: .override,              of: .callable,          unconditional: true):
            return 
                (
                    (source,  .is(.override(of: target))), 
                    (target, .has(.override(    source)))
                ) 
         
        case    (.associatedtype,   is: .requirement,           of: .protocol,          unconditional: true),
                (.callable(_),      is: .requirement,           of: .protocol,          unconditional: true),
                (.associatedtype,   is: .optionalRequirement,   of: .protocol,          unconditional: true),
                (.callable(_),      is: .optionalRequirement,   of: .protocol,          unconditional: true):
            return 
                (
                    (source,  .is(.requirement(of: target))), 
                    (target,  .is(  .interface(of: source)))
                ) 
         
        case    (.callable(_),      is: .defaultImplementation, of: .callable(_),       unconditional: true):
            return 
                (
                    (source,  .is(.implementation(of: target))), 
                    (target, .has(.implementation(    source)))
                ) 
        
        case (_, is: _, of: _, unconditional: false):
            // ``Edge.init(from:)`` should have thrown a ``JSON.LintingError`
            fatalError("unreachable")
        
        case (let source, is: let label, of: let target, unconditional: true):
            throw Symbol.RelationshipError.miscegenation(source, cannotBe: label, of: target)
        }
    }
}

extension Package 
{
    func generateIdeology<Symbols>(for cultures:[Module.Index], 
        from speeches:[[Symbol.Statement]], 
        about symbols:[Symbols]) 
        throws -> [Module.Index: Module.Beliefs]
        where Symbols:Sequence, Symbols.Element == Symbol.Index
    {
        // yes, a four-dimensional collection! we need to know:
        //  1.  who the perpetrator was 
        //  2.  who the subject package was 
        //  3.  who the subject symbol was 
        //  4.  what the perpetrator’s opinions about that symbol were
        var ideology:[Module.Index: Module.Beliefs] = [:]
            ideology.reserveCapacity(cultures.count)
        for (culture, (statements, symbols)):(Module.Index, ([Symbol.Statement], Symbols)) in 
            zip(cultures, zip(speeches, symbols))
        {
            // reserve a spot for *every* symbol, even if it has no relationships            
            var facts:[Symbol.Index: [Symbol.Relationship]] = 
                .init(symbols.map { ($0, []) }) { $1 }
            var beliefs:Module.Beliefs = .init()
            
            for (subject, predicate):Symbol.Statement in statements 
            {
                switch predicate
                {
                case  .is(let role):
                    guard culture == subject.module
                    else 
                    {
                        throw Symbol.RelationshipError
                            .unauthorized(culture, says: subject, is: role)
                    }
                case .has(let trait):
                    guard culture == subject.module
                    else 
                    {
                        beliefs.opinions[subject.module.package, default: [:]][subject, default: []]
                            .append(trait)
                        continue
                    }
                }
                if case nil = facts[subject]?.append(predicate)
                {
                    fatalError("unreachable")
                }
            }
            
            beliefs.facts.reserveCapacity(facts.count)
            for (symbol, facts):(Symbol.Index, [Symbol.Relationship]) in facts
            {
                beliefs.facts[symbol] = 
                    try .init(validating: facts, as: self[local: symbol].color)
            }
            
            ideology[culture] = beliefs
        }
        // ratify opinions that relate to the same package 
        for source:Dictionary<Module.Index, Module.Beliefs>.Index in ideology.indices
        {
            guard let stereotypes:[Symbol.Index: [Symbol.Trait]] = 
                ideology.values[source].opinions.removeValue(forKey: self.index)
            else 
            {
                continue 
            }
            let perpetrator:Module.Index = ideology.keys[source]
            for (subject, traits):(Symbol.Index, [Symbol.Trait]) in stereotypes 
            {
                guard let target:Dictionary<Module.Index, Module.Beliefs>.Index = 
                    ideology.index(forKey: subject.module)
                else 
                {
                    fatalError("unreachable...?")
                }
                if case nil = ideology.values[target]
                    .facts[subject]?
                    .identities[perpetrator, default: .init()]
                    .update(with: traits, as: self[local: subject].color)
                {
                    fatalError("unreachable")
                }
            }
        }
        return ideology
    }
}

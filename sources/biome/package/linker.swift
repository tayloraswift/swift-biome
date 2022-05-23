extension Package 
{
    func relationships<Modules, Symbols>(_ modules:Modules, between symbols:Symbols) 
        throws -> 
    (
        facts:[Symbol.Index: Symbol.Relationships], 
        opinions:[Index: [Symbol.Index: [Symbol.Trait]]]
    )
        where   Modules:Sequence, Modules.Element == (Module.Index, [Symbol.Statement]),
                Symbols:Sequence, Symbols.Element ==  Symbol.Index 
    {
        var facts:[Symbol.Index: [Symbol.Relationship]] = 
            .init(uniqueKeysWithValues: symbols.map { ($0, []) })
        var opinions:[Index: [Symbol.Index: [Symbol.Trait]]] = [:]
        
        for (culture, statements):(Module.Index, [Symbol.Statement]) in modules
        {
            for (subject, predicate):Symbol.Statement in statements 
            {
                switch predicate
                {
                case  .is(let role):
                    guard culture         == subject.module
                    else 
                    {
                        throw Symbol.RelationshipError
                            .unauthorized(culture, says: subject, is: role)
                    }
                case .has(let trait):
                    guard culture.package == subject.module.package
                    else 
                    {
                        opinions[subject.module.package, default: [:]][subject, default: []]
                            .append(trait)
                        continue
                    }
                }
                if case nil = facts[subject]?.append(predicate)
                {
                    fatalError("unreachable")
                }
            }
        }
        var relationships:[Symbol.Index: Symbol.Relationships] = [:] 
            relationships.reserveCapacity(facts.count)
        for (symbol, facts):(Symbol.Index, [Symbol.Relationship]) in facts
        {
            relationships[symbol] = 
                try .init(validating: facts, as: self[local: symbol].color)
        }
        return (relationships, opinions)
    }
    func statements<Modules>(_ modules:Modules, given ecosystem:Ecosystem)
        throws -> 
    (
        statements:[[Symbol.Statement]], 
        sponsorships:[Symbol.Sponsorship]
    )
        where Modules:Sequence, Modules.Element == (Module.Graph, Scope)
    {
        var sponsorships:[Symbol.Sponsorship] = []
        let statements:[[Symbol.Statement]] = try modules.map 
        {
            let (graph, scope):(Module.Graph, Scope) = $0
            
            // if we have `n` edges, we will get between `n` and `2n` statements
            var statements:[Symbol.Statement] = []
                statements.reserveCapacity(graph.edges.reduce(0) { $0 + $1.count })
            for edge:Edge in graph.edges.joined()
            {
                let constraints:[Generic.Constraint<Symbol.Index>] = 
                    try edge.constraints.map { try $0.map(scope.index(of:)) }
                let (source, target):(Symbol.Index, Symbol.Index) = 
                (
                    try scope.index(of: edge.source),
                    try scope.index(of: edge.target)
                )
                
                switch try self.statements(when: source, is: edge.kind, of: target, 
                    where: constraints, given: ecosystem)
                {
                case (let source?,  let target):
                    statements.append(source)
                    statements.append(target)
                case (nil,          let target):
                    statements.append(target)
                }
                
                // this fails quite frequently. we don’t have a great solution for this.
                if  let origin:Symbol.ID = edge.origin, 
                    let origin:Symbol.Index = try? scope.index(of: origin)
                {
                    sponsorships.append((source, by: origin))
                }
            }
            return statements
        }
        return (statements, sponsorships)
    }
    
    private 
    func statements(when source:Symbol.Index, is label:Edge.Kind, of target:Symbol.Index, 
        where constraints:[Generic.Constraint<Symbol.Index>], given ecosystem:Ecosystem)
        throws -> (source:Symbol.Statement?, target:Symbol.Statement)
    {
        switch  
        (
                self[source]?.color ?? ecosystem[source].color,
            is: label,
            of: self[target]?.color ?? ecosystem[target].color,
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


/* mutating 
func deduplicate(_ sponsored:Symbol.Index, against papers:String, from sponsor:Symbol.Index) 
    throws
{
    switch self[sponsored]?.legality
    {
    case nil:
        // cannot sponsor symbols from another package (but symbols in 
        // another package can sponsor symbols in this package)
        
        // FIXME: we need to handle this error! it indicates that data is 
        // also being duplicated ELSEWHERE
        
        // throw Symbol.SponsorshipError.unauthorized(self.package, says: sponsored, isSponsoredBy: sponsor)
        break
    
    case .sponsored(by: sponsor):
        // documentation has already been de-deduplicated
        break 
    
    case .sponsored(by: let other): 
        throw Symbol.SponsorshipError.disputed(sponsored, isSponsoredBy: other, and: sponsor)
    
    case .undocumented?, .documented(papers)?:
        self.nodes[sponsored.offset].legality = .sponsored(by: sponsor)
    
    case .documented(_):
        // a small number of symbols using fakes are actually documented, 
        // and should not be deported. 
        // print("warning: recovered documentation for symbol \(self.nodes[sponsored.offset].vertex.path)")
        // print("> sponsor’s documentation:")
        // print(papers)
        // print("> alien’s documentation:")
        // print(recovered)
        // print("------------")
        break
    }
} */

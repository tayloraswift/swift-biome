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

extension Package 
{
    func beliefs<Symbols>(_ statements:[[Symbol.Statement]], about symbols:[Symbols], 
        cultures:[Module.Index]) 
        throws -> [Module.Index: Module.Beliefs]
        where Symbols:Sequence, Symbols.Element ==  Symbol.Index 
    {
        // yes, a four-dimensional collection! we need to know:
        //  1.  who the perpetrator was 
        //  2.  who the subject package was 
        //  3.  who the subject symbol was 
        //  4.  what the perpetrator’s opinions about that symbol were
        var ideologies:[Module.Index: Module.Beliefs] = [:]
            ideologies.reserveCapacity(cultures.count)
        for (culture, (statements, symbols)):(Module.Index, ([Symbol.Statement], Symbols)) in 
            zip(cultures, zip(statements, symbols))
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
            
            ideologies[culture] = beliefs
        }
        // ratify opinions that relate to the same package 
        for source:Dictionary<Module.Index, Module.Beliefs>.Index in ideologies.indices
        {
            guard let stereotypes:[Symbol.Index: [Symbol.Trait]] = 
                ideologies.values[source].opinions.removeValue(forKey: self.index)
            else 
            {
                continue 
            }
            let perpetrator:Module.Index = ideologies.keys[source]
            for (subject, traits):(Symbol.Index, [Symbol.Trait]) in stereotypes 
            {
                guard let target:Dictionary<Module.Index, Module.Beliefs>.Index = 
                    ideologies.index(forKey: subject.module)
                else 
                {
                    fatalError("unreachable...?")
                }
                if case nil = ideologies.values[target]
                    .facts[subject]?
                    .identities[perpetrator, default: .init()]
                    .update(with: traits, as: self[local: subject].color)
                {
                    fatalError("unreachable")
                }
            }
        }
        return ideologies
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

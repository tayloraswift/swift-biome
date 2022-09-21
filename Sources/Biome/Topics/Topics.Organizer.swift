import Notebook

infix operator |<| :ComparisonPrecedence 

extension Path 
{
    /// Orders two paths first by final component, and then by scope.
    static 
    func |<| (lhs:Self, rhs:Self) -> Bool 
    {
        if lhs.last < rhs.last 
        {
            return true 
        }
        else if lhs.last == rhs.last 
        {
            return lhs.prefix.lexicographicallyPrecedes(rhs.prefix)
        }
        else 
        {
            return false 
        }
    }
}

extension _Topics 
{
    enum List:String, CaseIterable, Hashable, Sendable 
    {
        case conformers         = "Conforming Types"
        case conformances       = "Conforms To"
        case subclasses         = "Subclasses"
        case implications       = "Implies"
        case refinements        = "Refinements"
        case implementations    = "Implemented By"
        case restatements       = "Restated By"
        case overrides          = "Overridden By"
    }
}
extension _Topics 
{
    struct Organizer 
    {
        var articles:[ArticleCard]
        var requirements:[Community: [SymbolCard]]
        var members:[Community: [Atom<Module>: Enclave<SymbolCard>]]
        var removed:[Community: [Atom<Module>: Enclave<SymbolCard>]]

        var implications:[Atom<Symbol>]

        var conformers:[Atom<Module>: Enclave<Generic.Conditional<Atom<Symbol>>>]
        var conformances:[Atom<Module>: Enclave<Generic.Conditional<Atom<Symbol>>>]
        var subclasses:[Atom<Module>: Enclave<Atom<Symbol>>]
        var refinements:[Atom<Module>: Enclave<Atom<Symbol>>]
        var implementations:[Atom<Module>: Enclave<Atom<Symbol>>]
        var restatements:[Atom<Module>: Enclave<Atom<Symbol>>]
        var overrides:[Atom<Module>: Enclave<Atom<Symbol>>]

        init() 
        {
            self.articles = []
            self.requirements = [:]

            // TODO:
            // every sublist has an enclave for the primary culture, even if it is empty. 
            // this is more css-grid friendly.

            self.members = [:]
            self.removed = [:]
            
            self.implications = []

            self.conformers = [:]
            self.conformances = [:]
            self.subclasses = [:]
            self.refinements = [:]
            self.implementations = [:]
            self.restatements = [:]
            self.overrides = [:]
        }
    }
}

extension _Topics.Organizer 
{
    mutating 
    func organize(_ traits:Branch.SymbolTraits, of host:_ReferenceCache.AtomicReference, 
        diacritic:Diacritic, 
        culture:_Topics.Culture,
        context:Package.Context, 
        cache:inout _ReferenceCache) throws
    {
        switch (host.community, host.shape) 
        {
        case (_, .requirement(of: _)?):
            for parrot:Atom<Symbol> in traits.downstream
            {
                self.restatements[diacritic.culture, default: .init(id: culture)]
                    .items.append(parrot)
            }
            for implementation:Atom<Symbol> in traits.implementations
            {
                self.implementations[diacritic.culture, default: .init(id: culture)]
                    .items.append(implementation)
            }
        
        case (.protocol, _): 
            for (conformer, constraints):(Atom<Symbol>, [Generic.Constraint<Atom<Symbol>>]) in 
                traits.conformers
            {
                self.conformers[diacritic.culture, default: .init(id: culture)]
                    .items.append(.init(conformer, where: constraints))
            }
            for refinement:Atom<Symbol> in traits.downstream
            {
                self.refinements[diacritic.culture, default: .init(id: culture)]
                    .items.append(refinement)
            }
            for member:Atom<Symbol> in traits.members
            {
                // The enclave may be different from the atom’s own culture.
                try self.add(member: member, to: diacritic.culture,
                    culture: culture, 
                    context: context, 
                    cache: &cache)
            }
        
        case (.concretetype(_), _): 
            for (conformance, constraints):(Atom<Symbol>, [Generic.Constraint<Atom<Symbol>>]) in 
                traits.conformances
            {
                self.conformances[diacritic.culture, default: .init(id: culture)]
                    .items.append(.init(conformance, where: constraints))
            }
            for subclass:Atom<Symbol> in traits.downstream
            {
                self.subclasses[diacritic.culture, default: .init(id: culture)]
                    .items.append(subclass)
            }
            for member:Atom<Symbol> in traits.members
            {
                // The enclave may be different from the atom’s own culture.
                try self.add(member: member, to: diacritic.culture,
                    culture: culture, 
                    context: context, 
                    cache: &cache)
            }
            for feature:Atom<Symbol> in traits.features
            {
                try self.add(feature: feature, to: diacritic, 
                    culture: culture, 
                    context: context, 
                    cache: &cache)
            }
        
        case (.callable(_), _):
            for override:Atom<Symbol> in traits.downstream
            {
                self.overrides[diacritic.culture, default: .init(id: culture)]
                    .items.append(override)
            }
        
        default: 
            break 
        }
    }
    private mutating 
    func add(member:Atom<Symbol>, to enclave:Atom<Module>, 
        culture:_Topics.Culture,
        context:Package.Context, 
        cache:inout _ReferenceCache) throws
    {
        try self.add(composite: .init(atomic: member), to: enclave, 
            culture: culture, 
            context: context, 
            cache: &cache)
    }
    private mutating 
    func add(feature:Atom<Symbol>, to diacritic:Diacritic, 
        culture:_Topics.Culture,
        context:Package.Context, 
        cache:inout _ReferenceCache) throws
    {
        try self.add(composite: .init(feature, diacritic), to: diacritic.culture, 
            culture: culture, 
            context: context, 
            cache: &cache)
    }
    private mutating 
    func add(composite:Composite, to enclave:Atom<Module>, 
        culture:_Topics.Culture,
        context:Package.Context,
        cache:inout _ReferenceCache) throws 
    {
        let community:Community = try cache.community(of: composite.base, context: context)
        let declaration:Declaration<Atom<Symbol>>? = context[composite.base.nationality]?
            .declaration(for: composite.base)
        let card:_Topics.SymbolCard = .init(composite: composite, 
            signature: declaration?.signature, 
            overview: context.documentation(for: composite.base)?.card)
        
        if case false? = declaration?.availability.isUsable 
        {
            self.removed[community, default: [:]][enclave, default: .init(id: culture)]
                .items.append(card)
        }
        else 
        {
            self.members[community, default: [:]][enclave, default: .init(id: culture)]
                .items.append(card)
        }
    }
}

extension _Topics.Organizer 
{
    mutating 
    func organize(_ roles:Branch.SymbolRoles, 
        context:Package.Context, 
        cache:inout _ReferenceCache) throws
    {
        switch roles 
        {
        case .one(let role):
            try self.add(role: role, context: context, cache: &cache)
        case .many(let roles):
            for role:Atom<Symbol> in roles 
            {
                try self.add(role: role, context: context, cache: &cache)
            }
        }
    }
    private mutating 
    func add(role:Atom<Symbol>, context:Package.Context, cache:inout _ReferenceCache) throws
    {
        // protocol roles may originate from a different package
        switch try cache.community(of: role, context: context)
        {
        case .protocol:
            self.implications.append(role)
        case let community:
            // this is always valid, because non-protocol roles are always 
            // requirements, and requirements always live in the same package as 
            // the protocol they are part of.
            let card:_Topics.SymbolCard = .init(composite: .init(atomic: role),
                signature: context.local.declaration(for: role)?.signature, 
                overview: context.documentation(for: role)?.card)
            self.requirements[community, default: []].append(card)
        }
    }
}

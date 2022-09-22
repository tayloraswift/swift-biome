import DOM
import Notebook

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
        var articles:[Card<String>.Unsorted]

        var requirements:[Community: [Card<Notebook<Highlight, Never>>.Unsorted]]

        var members:[Community: [Atom<Module>: Enclave<Card<Notebook<Highlight, Never>>.Unsorted>]]
        var removed:[Community: [Atom<Module>: Enclave<Card<Notebook<Highlight, Never>>.Unsorted>]]

        var implications:[Item<Void>]

        var conformers:[Atom<Module>: Enclave<Item<[Generic.Constraint<String>]>>]
        var conformances:[Atom<Module>: Enclave<Item<[Generic.Constraint<String>]>>]

        var subclasses:[Atom<Module>: Enclave<Item<Void>>]
        var refinements:[Atom<Module>: Enclave<Item<Void>>]
        var implementations:[Atom<Module>: Enclave<Item<Void>>]
        var restatements:[Atom<Module>: Enclave<Item<Void>>]
        var overrides:[Atom<Module>: Enclave<Item<Void>>]

        init() 
        {
            self.articles = []

            self.requirements = [:]

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
    func organize(_ traits:Branch.SymbolTraits, of host:SymbolReference, 
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
                self.restatements[diacritic.culture, default: .init(culture)]
                    .elements.append(try .init(parrot, context: context, cache: &cache))
            }
            for implementation:Atom<Symbol> in traits.implementations
            {
                self.implementations[diacritic.culture, default: .init(culture)]
                    .elements.append(try .init(implementation, context: context, cache: &cache))
            }
        
        case (.protocol, _): 
            for (conformer, constraints):(Atom<Symbol>, [Generic.Constraint<Atom<Symbol>>]) in 
                traits.conformers
            {
                self.conformers[diacritic.culture, default: .init(culture)]
                    .elements.append(try .init(conformer, where: constraints, 
                        context: context, 
                        cache: &cache))
            }
            for refinement:Atom<Symbol> in traits.downstream
            {
                self.refinements[diacritic.culture, default: .init(culture)]
                    .elements.append(try .init(refinement, context: context, cache: &cache))
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
                self.conformances[diacritic.culture, default: .init(culture)]
                    .elements.append(try .init(conformance, where: constraints, 
                        context: context, 
                        cache: &cache))
            }
            for subclass:Atom<Symbol> in traits.downstream
            {
                self.subclasses[diacritic.culture, default: .init(culture)]
                    .elements.append(try .init(subclass, context: context, cache: &cache))
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
                self.overrides[diacritic.culture, default: .init(culture)]
                    .elements.append(try .init(override, context: context, cache: &cache))
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
        guard   let declaration:Declaration<Atom<Symbol>> = 
                    context[composite.base.nationality]?.declaration(for: composite.base)
        else 
        {
            throw _DeclarationLoadingError.init()
        }

        let overview:DOM.Flattened<GlobalLink.Presentation> = 
            context.documentation(for: composite.base)?.card ?? .init()
        
        let base:SymbolReference = try cache.load(composite.base, context: context)
        let card:_Topics.Card<Notebook<Highlight, Never>>, 
            key:_Topics.SortingKey
        if  let compound:Compound = composite.compound 
        {
            let host:SymbolReference = try cache.load(compound.host, context: context)

            card = .init(signature: declaration.signature, 
                overview: overview, 
                uri: try cache.uri(of: compound, context: context))
            key = .compound((host.path, base.name))
        }
        else 
        {
            card = .init(signature: declaration.signature, 
                overview: overview, 
                uri: base.uri)
            key = .atomic(base.path)
        }
        
        if  declaration.availability.isUsable 
        {
            self.members[base.community, default: [:]][enclave, default: .init(culture)]
                .elements.append((card, key))
        }
        else 
        {
            self.removed[base.community, default: [:]][enclave, default: .init(culture)]
                .elements.append((card, key))
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
        let symbol:SymbolReference = try cache.load(role, context: context)
        switch symbol.community
        {
        case .protocol:
            self.implications.append(try .init(symbol, context: context, cache: &cache))
        case let community:
            // this is always valid, because non-protocol roles are always 
            // requirements, and requirements always live in the same package as 
            // the protocol they are part of.
            guard   let declaration:Declaration<Atom<Symbol>> = 
                        context.local.declaration(for: role)
            else 
            {
                throw _DeclarationLoadingError.init()
            }
            let card:_Topics.Card<Notebook<Highlight, Never>> = .init(
                    signature: declaration.signature, 
                    overview: context.documentation(for: role)?.card ?? .init(), 
                    uri: symbol.uri)
            self.requirements[community, default: []].append((card, .atomic(symbol.path)))
        }
    }
}

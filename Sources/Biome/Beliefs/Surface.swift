import SymbolGraphs

struct Belief 
{
    enum Predicate 
    {
        case `is`(Symbol.Role<Tree.Position<Symbol>>)
        case has(Symbol.Trait<Tree.Position<Symbol>>)
    }

    let subject:Tree.Position<Symbol>
    let predicate:Predicate

    init(_ subject:Tree.Position<Symbol>, _ predicate:Predicate)
    {
        self.subject = subject 
        self.predicate = predicate
    }
}
struct Surface 
{
    private(set)
    var missingModules:Set<Branch.Position<Module>>, 
        missingSymbols:Set<Branch.Position<Symbol>>, 
        missingHosts:Set<Branch.Diacritic>
    
    @available(*, deprecated, renamed: "local")
    var symbols:[Tree.Position<Symbol>: Symbol.Facts<Tree.Position<Symbol>>]
    {
        self.local 
    }
    @available(*, deprecated, renamed: "foreign")
    var diacritics:[Tree.Diacritic: Symbol.Traits<Tree.Position<Symbol>>]
    {
        self.foreign
    }

    private(set)
    var local:[Tree.Position<Symbol>: Symbol.Facts<Tree.Position<Symbol>>]
    private(set)
    var foreign:[Tree.Diacritic: Symbol.Traits<Tree.Position<Symbol>>]
    
    init(branch:__shared Branch, fasces:Fasces)
    {
        self.local = [:]
        self.foreign = [:]

        self.missingModules = []
        self.missingSymbols = []
        self.missingHosts = []

        // TODO: this should not require an unbounded range slice
        for module:Module in branch.modules[...] 
        {
            self.missingModules.insert(module.index)
            for (range, _):(Range<Symbol.Offset>, Branch.Position<Module>) in module.symbols 
            {
                for offset:Symbol.Offset in range 
                {
                    self.missingSymbols.insert(.init(module.index, offset: offset))
                }
            }
        }
        for (module, divergence):(Branch.Position<Module>, Module.Divergence) in 
            branch.modules.divergences
        {
            for (range, _):(Range<Symbol.Offset>, Branch.Position<Module>) in divergence.symbols 
            {
                for offset:Symbol.Offset in range 
                {
                    self.missingSymbols.insert(.init(module, offset: offset))
                }
            }
        }
        for fascis:Fascis in fasces 
        {
            for module:Module in fascis.modules 
            {
                self.missingModules.insert(module.index)
            }

            fatalError("unimplemented")
        }
    }

    mutating 
    func update(with edges:[SymbolGraph.Edge<Int>], interface:ModuleInterface, context:Packages)
    {
        let (beliefs, errors):([Belief], [ModuleInterface.LookupError]) = 
            interface.symbols.translate(edges: edges, context: context)
        
        if !errors.isEmpty 
        {
            print("warning: dropped \(errors.count) edges")
        }
        
        self.insert(beliefs, symbols: interface.citizenSymbols, context: context)
    }

    private mutating 
    func insert(_ beliefs:[Belief], symbols:ModuleInterface.Citizens<Symbol>, context:Packages) 
    {
        var opinions:[Tree.Position<Symbol>: [Symbol.Trait<Tree.Position<Symbol>>]] = [:]
        var traits:[Tree.Position<Symbol>: [Symbol.Trait<Tree.Position<Symbol>>]] = [:]
        var roles:[Tree.Position<Symbol>: [Symbol.Role<Tree.Position<Symbol>>]] = [:]
        for belief:Belief in beliefs 
        {
            switch (symbols.culture == belief.subject.contemporary.culture, belief.predicate)
            {
            case (false,  .is(_)):
                fatalError("unimplemented")
            case (false, .has(let trait)):
                opinions[belief.subject, default: []].append(trait)
            case (true,  .has(let trait)):
                traits[belief.subject, default: []].append(trait)
            case (true,   .is(let role)):
                roles[belief.subject, default: []].append(role)
            }
        }

        self.missingModules.remove(symbols.culture)
        for symbol:Tree.Position<Symbol>? in symbols 
        {
            if let symbol:Tree.Position<Symbol>
            {
                self.missingSymbols.remove(symbol.contemporary)
                self.local[symbol] = .init(
                    traits: traits.removeValue(forKey: symbol) ?? [], 
                    roles: roles.removeValue(forKey: symbol) ?? [], 
                    as: context[global: symbol].community) 
            }
        }
        guard traits.isEmpty, roles.isEmpty 
        else 
        {
            fatalError("unimplemented")
        }
        for (subject, traits):(Tree.Position<Symbol>, [Symbol.Trait<Tree.Position<Symbol>>]) in 
            opinions
        {
            let traits:Symbol.Traits<Tree.Position<Symbol>> = .init(traits, 
                as: context[global: subject].community)
            
            if  subject.package == symbols.culture.package 
            {
                self.local[subject]?.update(acceptedCulture: symbols.culture, with: traits)
            }
            else 
            {
                let diacritic:Tree.Diacritic = .init(host: subject, culture: symbols.culture)
                self.missingHosts.remove(diacritic.contemporary)
                self.foreign[diacritic] = traits
            }
        }
    }

    private mutating 
    func add(member:Tree.Position<Symbol>, to scope:Tree.Position<Symbol>)
    {
        if  scope.contemporary.culture == member.contemporary.culture 
        {
            self.local[scope]?.primary
                .members.insert(member)
        }
        else 
        {
            self.local[scope]?.accepted[member.contemporary.culture, default: .init()]
                .members.insert(member)
        }
    }
}

extension Surface 
{
    mutating 
    func inferScopes(for branch:inout Branch, fasces:Fasces, stems:Route.Stems)
    {
        self.inferScopes(for: &branch.symbols, 
            routes: fasces.routes(layering: branch.routes, branch: branch.index), 
            stems: stems)
    }
    private mutating 
    func inferScopes(for symbols:inout Branch.Buffer<Symbol>, 
        routes:Fasces.AugmentedRoutingView, 
        stems:Route.Stems)
    {
        for (member, facts):(Tree.Position<Symbol>, Symbol.Facts<Tree.Position<Symbol>>) in 
            self.local
        {
            // we know that every key in ``Surface.symbols`` is part of the current 
            // package, and that they are all part of the current timeline, so it 
            // is safe to compare contemporary offsets.
            if member.contemporary.offset < symbols.startIndex
            {
                continue 
            }
            if let shape:Symbol.Shape<Tree.Position<Symbol>> = facts.shape 
            {
                // already have a shape from a member or requirement belief
                symbols[contemporary: member.contemporary].shape = shape
                continue 
            }

            let symbol:Symbol = symbols[contemporary: member.contemporary]
            guard   case nil = symbol.shape, 
                    let scope:Path = .init(symbol.path.prefix)
            else 
            {
                continue 
            }
            //  attempt to re-parent this symbol using lexical lookup. 
            //  this is a *very* heuristical process.
            if  let scope:Route.Key = stems[symbol.route.namespace, straight: scope]
            {
                let selection:_Selection<Tree.Position<Symbol>>? = routes.select(scope)
                {
                    $1.natural.map($0.pluralize(_:))
                }
                if case .one(let scope)? = selection 
                {
                    symbols[contemporary: member.contemporary].shape = .member(of: scope)
                    self.add(member: member, to: scope) 
                    continue 
                }
            }
            
            print("warning: orphaned symbol \(symbol)")
        }
    }
}
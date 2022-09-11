import URI 

struct _Scope 
{
    let namespace:Branch.Position<Module>
    let path:[String]

    init(_ namespace:Branch.Position<Module>, _ path:[String] = [])
    {
        self.namespace = namespace 
        self.path = path
    }
}

extension Package 
{
    struct _Pinned:Sendable 
    {
        let package:Package 
        let version:_Version
        private 
        let fasces:Fasces 

        @available(*, deprecated)
        var _fasces:Fasces 
        {
            self.fasces
        }
        
        init(_ package:Package, version:_Version)
        {
            self.package = package
            self.version = version
            self.fasces = self.package.tree.fasces(through: self.version)
        }

        private 
        func metadata(foreign diacritic:Branch.Diacritic) -> Symbol.ForeignMetadata?
        {
            self.package.metadata.foreign.value(of: diacritic, 
                field: \.metadata, 
                in: self.fasces.foreign) ?? nil
        }
        private 
        func metadata(local symbol:Branch.Position<Symbol>) -> Symbol.Metadata?
        {
            self.package.metadata.symbols.value(of: symbol, 
                field: (\.metadata, \.metadata), 
                in: self.fasces.symbols) ?? nil
        }
        private 
        func metadata(local module:Branch.Position<Module>) -> Module.Metadata?
        {
            self.package.metadata.modules.value(of: module, 
                field: (\.metadata, \.metadata), 
                in: self.fasces.modules) ?? nil
        }
        func exists(_ symbol:Branch.Position<Symbol>) -> Bool
        {
            if case _? = self.metadata(local: symbol)
            {
                return true 
            }
            else 
            {
                return false 
            }
        }
        func exists(_ composite:Branch.Composite) -> Bool
        {
            guard let host:Branch.Position<Symbol> = composite.host 
            else 
            {
                return self.exists(composite.base)
            }
            if self.package.index == host.package
            {
                return self.metadata(local: host)?
                    .contains(feature: composite) ?? false 
            }
            else 
            {
                return self.metadata(foreign: composite.diacritic)?
                    .contains(feature: composite.base) ?? false
            }
        }
        func resolve(composite:Branch.Composite) -> ResolvedLink?
        {
            self.exists(composite) ? .composite(composite) : nil
        }

        func _resolve(_ uri:URI, scope:_Scope?, stems:Route.Stems) 
            throws -> _Selection<ResolvedLink>?
        {
            var host:Symbol.ID? = nil
            var base:Symbol.ID? = nil
            for (key, value):(String, String) in uri.query ?? [] 
            {
                // slightly different from the parser in `PluralReference.swift`
                if  let key:PluralReference.Parameter = .init(rawValue: key), 
                    let id:Symbol.ID = try? USR.Rule<String.Index>.OpaqueName.parse(value.utf8)
                {
                    switch key 
                    {
                    case .host: host = id
                    case .base: base = id 
                    case .culture: continue
                    }
                }
            }

            let expression:_SymbolLink = .init(path: try .init(uri.path), 
                base: base, 
                host: host)
            let link:_SymbolLink = expression.revealed 
            if  let selection:_Selection<ResolvedLink> = self.resolve(link, 
                    scope: scope, 
                    stems: stems, 
                    where: self.resolve(composite:))
            {
                return selection 
            }
            if  let link:_SymbolLink = link.outed, 
                let selection:_Selection<ResolvedLink> = self.resolve(link, 
                    scope: scope, 
                    stems: stems, 
                    where: self.resolve(composite:))
            {
                return selection
            }
            else 
            {
                return nil 
            }
        }
        func resolve(_ link:_SymbolLink, scope:_Scope?, stems:Route.Stems, 
            where filter:(Branch.Composite) throws -> ResolvedLink?) 
            rethrows -> _Selection<ResolvedLink>?
        {
            if let scope:_Scope 
            {
                for level:Int in scope.path.indices.reversed()
                {
                    if  let key:Route.Key = 
                            stems[scope.namespace, scope.path.prefix(through: level), link],
                        let selection:_Selection<ResolvedLink> = 
                            try self.fasces.routes.select(key, where: filter)
                    {
                        return selection
                    }
                }
                if  let key:Route.Key = stems[scope.namespace, link],
                    let selection:_Selection<ResolvedLink> = 
                        try self.fasces.routes.select(key, where: filter)
                {
                    return selection
                }
            }
            guard   let namespace:Module.ID = link.first.map(Module.ID.init(_:)), 
                    let namespace:Tree.Position<Module> = self.fasces.modules.find(namespace)
            else 
            {
                return nil
            }
            if let link:_SymbolLink = link.suffix 
            {
                return try stems[namespace.contemporary, link].flatMap 
                {
                    try self.fasces.routes.select($0, where: filter)
                }
            }
            else 
            {
                return .one(.module(namespace.contemporary))
            }
        }
    }
}
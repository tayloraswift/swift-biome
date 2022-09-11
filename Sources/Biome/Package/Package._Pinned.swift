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

    func scan<T>(concatenating link:_SymbolLink, stems:Route.Stems, 
        until match:(Route.Key) throws -> T?) rethrows -> T?
    {
        for level:Int in self.path.indices.reversed()
        {
            if  let key:Route.Key = 
                    stems[self.namespace, self.path.prefix(through: level), link],
                let match:T = try match(key)
            {
                return match
            }
        }
        return try stems[self.namespace, link].flatMap(match)
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

        var routes:Fasces.RoutingView 
        {
            self.fasces.routes
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

        func resolve(_ link:_SymbolLink, scope:_Scope?, stems:Route.Stems) 
            -> _SymbolLink.Resolution?
        {
            if  let resolution:_SymbolLink.Resolution = self.resolve(link, 
                    scope: scope, 
                    stems: stems, 
                    where: self.exists(_:))
            {
                return resolution 
            }
            if  let link:_SymbolLink = link.outed, 
                let resolution:_SymbolLink.Resolution = self.resolve(link, 
                    scope: scope, 
                    stems: stems, 
                    where: self.exists(_:))
            {
                return resolution
            }
            else 
            {
                return nil 
            }
        }
        private 
        func resolve(_ link:_SymbolLink, scope:_Scope?, stems:Route.Stems, 
            where predicate:(Branch.Composite) throws -> Bool) 
            rethrows -> _SymbolLink.Resolution?
        {
            if  let scope:_Scope, 
                let selection:_Selection<Branch.Composite> = try scope.scan(concatenating: link, 
                    stems: stems, 
                    until: { try self.routes.select($0, where: predicate) })
            {
                return .init(selection)
            }
            guard   let namespace:Module.ID = link.first.map(Module.ID.init(_:)), 
                    let namespace:Tree.Position<Module> = self.fasces.modules.find(namespace)
            else 
            {
                return nil
            }
            guard let link:_SymbolLink = link.suffix 
            else 
            {
                return .module(namespace.contemporary)
            }
            if  let key:Route.Key = stems[namespace.contemporary, link], 
                let selection:_Selection<Branch.Composite> = try self.routes.select(key, 
                    where: predicate)
            {
                return .init(selection)
            }
            else 
            {
                return nil
            }
        }
    }
}
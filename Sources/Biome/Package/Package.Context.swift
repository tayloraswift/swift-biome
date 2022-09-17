extension Package 
{
    // this isn’t *quite* ``SurfaceBuilder.Context``, because ``local`` is pinned here.
    struct Context:Sendable 
    {
        let upstream:[Index: _Pinned]
        let local:_Pinned 

        init(local:_Pinned, context:__shared Packages)
        {
            self.init(local: local, pins: local.package.tree[local.version].pins, 
                context: context)
        }
        init(local:_Pinned, pins:__shared [Index: _Version], context:__shared Packages)
        {
            self.local = local 
            var upstream:[Index: _Pinned] = .init(minimumCapacity: pins.count)
            for (index, version):(Index, _Version) in pins 
            {
                upstream[index] = .init(context[index], version: version)
            }
            self.upstream = upstream
        }

        subscript(nationality:Index) -> _Pinned?
        {
            _read 
            {
                yield   self.local.nationality == nationality ? 
                        self.local : self.upstream[nationality]
            }
        }
    }
}
extension Package.Context 
{
    func load(_ symbol:Branch.Position<Symbol>) -> Symbol?
    {
        self[symbol.nationality]?.load(local: symbol) 
    }
}
extension Package.Context 
{
    /// Returns the address of the specified package, if it is defined in this context.
    /// 
    /// The returned address always includes the package name, even if it is the 
    /// standard library or one of the core libraries.
    ///
    /// This method is isotropic; it does not matter which of the packages in 
    /// this context is the local package.
    func address(of package:Package.Index, function:Service.Function = .documentation(.symbol)) 
        -> Address?
    {
        guard let pinned:Package.Pinned = self[package]
        else 
        {
            return nil 
        }
        let global:Address.Global = .init(
            residency: pinned.package.id, 
            version: pinned.package.tree.abbreviate(pinned.version))
        return .init(function: .documentation(.symbol), global: _move global)
    }
    /// Returns the address of the specified module, if it is defined in this context.
    /// 
    /// This method is isotropic; it does not matter which of the packages in 
    /// this context is the local package.
    func address(of module:Branch.Position<Module>) -> Address?
    {
        guard   let nationality:Package.Pinned = self[module.nationality], 
                let namespace:Module = nationality.load(local: module)
        else 
        {
            return nil 
        }
        let global:Address.Global = .init(
            residency: module.nationality.isCommunityPackage ? nationality.package.id : nil, 
            version: nationality.package.tree.abbreviate(nationality.version), 
            local: .init(namespace: namespace.id))
        return .init(function: .documentation(.symbol), global: _move global)
    }
    /// Returns the address of the specified article, if it is defined in this context.
    /// 
    /// This method is isotropic; it does not matter which of the packages in 
    /// this context is the local package.
    func address(of article:Branch.Position<Article>) -> Address?
    {
        guard   let nationality:Package.Pinned = self[article.nationality], 
                let namespace:Module = nationality.load(local: article.culture), 
                let path:Path = nationality.load(local: article)?.path
        else 
        {
            return nil 
        }
        let local:Address.Local = .init(namespace: namespace.id, 
            symbolic: .init(path: path, orientation: .straight))
        let global:Address.Global = .init(
            residency: article.nationality.isCommunityPackage ? nationality.package.id : nil, 
            version: nationality.package.tree.abbreviate(nationality.version), 
            local: _move local)
        return .init(function: .documentation(.symbol), global: _move global)
    }
    /// Returns the address of the specified composite, if all of its components 
    /// are defined in this context.
    /// 
    /// This method is isotropic; it does not matter which of the packages in 
    /// this context is the local package.
    func address(of composite:Branch.Composite, disambiguate:Bool = true) -> Address?
    {
        guard   let base:Symbol = self.load(composite.base), 
                let nationality:Package.Pinned = self[composite.nationality]
        else 
        {
            return nil 
        }

        var address:Address.Symbolic 
        let namespace:Branch.Position<Module>
        if  let host:Branch.Position<Symbol> = composite.host
        {
            guard   let host:Symbol = self.load(host), 
                    let stem:Route.Stem = host.kind.path
            else 
            {
                return nil 
            }

            var path:Path = host.path 
                path.append(base.name)
            
            address = .init(path: _move path, orientation: base.orientation)
            namespace = host.namespace

            if disambiguate 
            {
                switch nationality.depth(of: .init(host.namespace, stem, base.route.leaf), 
                    host: composite.diacritic.host, 
                    base: composite.base)
                {
                case nil: 
                    break 
                case .base?: 
                    address.base = base.id 
                case .host?:
                    address.base = base.id 
                    address.host = host.id 
                }
            }
        }
        else 
        {
            address = .init(path: base.path, orientation: base.orientation)
            namespace = base.namespace
            
            if disambiguate 
            {
                switch nationality.depth(of: base.route, natural: composite.base)
                {
                case nil: 
                    break 
                case .base?: 
                    address.base = base.id 
                }
            }
        }
        let residency:Package.Index = namespace.nationality
        if  residency != composite.nationality 
        {
            address.nationality = .init(id: nationality.package.id, 
                version: nationality.package.tree.abbreviate(nationality.version))
        }
        guard   let residence:Package.Pinned = self[residency],
                let namespace:Module = residence.load(local: namespace)
        else 
        {
            return nil
        }
        let local:Address.Local = .init(namespace: namespace.id, symbolic: address)
        let global:Address.Global = .init(
            residency: residency.isCommunityPackage ? residence.package.id : nil, 
            version: residence.package.tree.abbreviate(residence.version), 
            local: _move local)
        return .init(function: .documentation(.symbol), global: _move global)
    }
}
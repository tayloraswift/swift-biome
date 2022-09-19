extension Package 
{
    // this isn’t *quite* ``SurfaceBuilder.Context``, because ``local`` is pinned here.
    struct Context:Sendable 
    {
        let upstream:[Index: Pinned]
        let local:Pinned 

        init(local:Pinned, context:__shared Packages)
        {
            self.init(local: local, pins: local.package.tree[local.version].pins, 
                context: context)
        }
        init(local:Pinned, pins:__shared [Index: Version], context:__shared Packages)
        {
            self.local = local 
            var upstream:[Index: Pinned] = .init(minimumCapacity: pins.count)
            for (index, version):(Index, Version) in pins 
            {
                upstream[index] = .init(context[index], version: version)
            }
            self.upstream = upstream
        }

        subscript(nationality:Index) -> Pinned?
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
    func load(_ symbol:Position<Symbol>) -> Symbol?
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
        self[package]?.address(function: function)
    }
    /// Returns the address of the specified module, if it is defined in this context.
    /// 
    /// This method is isotropic; it does not matter which of the packages in 
    /// this context is the local package.
    func address(of module:Position<Module>) -> Address?
    {
        self[module.nationality]?.address(local: module)
    }
    /// Returns the address of the specified article, if it is defined in this context.
    /// 
    /// This method is isotropic; it does not matter which of the packages in 
    /// this context is the local package.
    func address(of article:Position<Article>) -> Address?
    {
        self[article.nationality]?.address(local: article)
    }
    /// Returns the address of the specified composite, if all of its components 
    /// are defined in this context.
    /// 
    /// This method is isotropic; it does not matter which of the packages in 
    /// this context is the local package.
    func address(of composite:Composite, disambiguate:Bool = true) -> Address?
    {
        guard   let base:Symbol = self.load(composite.base), 
                let nationality:Package.Pinned = self[composite.nationality]
        else 
        {
            return nil 
        }

        var address:Address.Symbolic 
        let namespace:Position<Module>
        if  let compound:Compound = composite.compound
        {
            guard   let host:Symbol = self.load(compound.host), 
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
                    compound: compound)
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
                switch nationality.depth(of: base.route, atom: composite.base)
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
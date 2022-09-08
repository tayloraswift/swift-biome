struct IdealReference 
{
    let namespace:Tree.Position<Module>
    let culture:Package._Pinned

    // this version may be different from the corresponding tree position!
    // let arrival:_Version
    let link:_SymbolLink?

    init?(_ plural:__owned PluralReference)
    {
        guard let first:String = plural.path.first
        else 
        {
            return nil
        }
        for namespace:Package in plural.namespaces 
        {
            let path:ArraySlice<String>

            let tag:Tag = .init(parsing: first)
            let arrival:_Version 
            if let version:_Version = namespace.tree.find(tag) 
            {
                arrival = version
                path = plural.path.dropFirst()
            }
            else if let version:_Version = namespace.tree.default 
            {
                arrival = version
                path = plural.path
            }
            else 
            {
                continue 
            }

            // we must parse the symbol link *now*, otherwise references to things 
            // like global vars (`Swift.min(_:_:)`) won’t work
            guard   let link:_SymbolLink = try? .init(path: _move path, 
                        base: plural.base, 
                        host: plural.host).revealed
            else 
            {
                // every article path is a valid symbol link (just with extra 
                // interceding hyphens). so if parsing failed, it was not a valid 
                // article path either.
                return nil 
            }
            //  we can store a module id in a ``Symbol/Link``, because every 
            //  ``Module/ID`` is a valid ``Symbol/Link/Component``.
            guard let module:Module.ID = (link.first?.string).map(Module.ID.init(_:)) 
            else 
            {
                continue 
            }

            let namespace:Package._Pinned = .init(namespace, version: arrival)
            if let module:Tree.Position<Module> = namespace.fasces.modules.find(module)
            {
                self.namespace = module 
                self.culture = plural.culture ?? namespace 
                self.link = link.suffix
                return 
            }
        }
        return nil
    }
}
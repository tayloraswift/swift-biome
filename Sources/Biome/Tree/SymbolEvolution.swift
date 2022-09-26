struct SymbolEvolution 
{
    struct Item
    {
        let label:Version.Selector 
        let address:Address 
    }

    private(set)
    var items:[Item]
}
// evolution requires *site-wide* context! this is because the set of package pins 
// can vary over the course of a package’s history, so it’s possible for a 
// past version to depend on a package that is not currently a dependency of 
// the package now. 
// this is relevant to API evolution because even though we know the USRs of the 
// base and host components, that does not necessarily mean the nationalities of those 
// components are constant, because USRs only encode local culture. 
// an example of this in “the wild” is if a package switches a dependency to another 
// upstream package that vends a module of the same name as the one the old dependency 
// vended.
extension SymbolEvolution
{
    init(for atomic:__shared Symbol.ID, 
        in local:__shared Package.Pinned, 
        context:__shared Packages)
    {
        self.items = []
        for branch:Branch in local.package.tree 
        {
            let detail:Int = branch.index == local.version.branch ? 8 : 1

            local.repinned(to: branch.revisions.indices.suffix(detail), of: branch)
            {
                (local:__owned Package.Pinned) in 

                guard   let symbol:Atom<Symbol>.Position = 
                            local.symbols.find(atomic),
                            local.exists(symbol.atom),
                        let metadata:Module.Metadata = 
                            local.metadata(local: symbol.culture)
                else 
                {
                    return 
                }

                let context:AnisotropicContext = .init(local: _move local,
                    metadata: metadata, 
                    context: context)
                
                if  let address:Address = context.local.address(of: symbol.atom, 
                        symbol: context.local.package.tree[local: symbol], 
                        context: context)
                {
                    let label:Version.Selector? = 
                        context.local.package.tree.abbreviate(context.local.version)
                    self.items.append(.init(label: label ?? .tag(branch.id), 
                        address: address))
                }
            }
        }
    }
    init(for compound:__shared Compound.ID, 
        in local:__shared Package.Pinned, 
        context:__shared Packages)
    {
        self.items = []
        for branch:Branch in local.package.tree 
        {
            let detail:Int = branch.index == local.version.branch ? 8 : 1

            local.repinned(to: branch.revisions.indices.suffix(detail), of: branch)
            {
                (local:__owned Package.Pinned) in 

                guard   let culture:Atom<Module>.Position = 
                            local.modules.find(compound.culture), 
                        let metadata:Module.Metadata = 
                            local.metadata(local: culture.atom)
                else 
                {
                    return 
                }

                let context:AnisotropicContext = .init(local: _move local,
                    metadata: metadata, 
                    context: context)
                
                if  let host:(position:Atom<Symbol>.Position, symbol:Symbol) = 
                        context.find(compound.host, linked: metadata.dependencies),
                    let base:(position:Atom<Symbol>.Position, symbol:Symbol) = 
                        context.find(compound.base, linked: metadata.dependencies),
                    // can’t think of why host would become equal to base, but hey, 
                    // anything can happen...
                    let compound:Compound = .init(
                        diacritic: .init(host: host.position.atom, culture: culture.atom), 
                        base: base.position.atom),
                        context.local.exists(compound),
                    let address:Address = context.local.address(of: compound, 
                        host: host.symbol, 
                        base: base.symbol, 
                        context: context)
                {
                    let label:Version.Selector? = 
                        context.local.package.tree.abbreviate(context.local.version)
                    self.items.append(.init(label: label ?? .tag(branch.id), 
                        address: address))
                }
            }
        }
    }
}
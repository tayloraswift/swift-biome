import HTML 

struct Evolution 
{
    struct Item
    {
        let label:Version.Selector 
        let uri:String?
    }

    struct Newer
    {
        let uri:String
    }

    private(set)
    var items:[Item], 
        newer:Newer?

    private 
    init(local:__shared Package.Pinned,
        functions:__shared Service.PublicFunction.Names, 
        address:(Package.Pinned) throws -> Address?) rethrows 
    {
        self.items = []
        self.newer = nil

        let current:Version = local.version 
        for branch:Branch in local.package.tree 
        {
            let detail:Int = branch.index == local.version.branch ? 8 : 1
            try local.repinned(to: branch.revisions.indices.suffix(detail), of: branch)
            {
                (local:Package.Pinned) in 

                guard local.version != current 
                else 
                {
                    self.items.append(.init(
                        label: local.selector ?? .tag(branch.id), 
                        uri: nil))
                    return 
                }
                if  let address:Address = try address(local)
                {
                    let label:Version.Selector = local.selector ?? .tag(branch.id)
                    let uri:String = address.uri(functions: functions).description
                    self.items.append(.init(label: label, uri: uri))
                    
                    if case local.version.revision? = branch.head, 
                            current.branch == branch.index
                    {
                        self.newer = .init(uri: uri)
                    }
                }
            }
        }
    }
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
extension Evolution
{
    init(local:__shared Package.Pinned, 
        functions:__shared Service.PublicFunction.Names)
    {
        self.init(local: local, functions: functions, address: Address.init(residency:))
    }
    
    init(for module:Atom<Module>.Position, 
        local:__shared Package.Pinned, 
        functions:__shared Service.PublicFunction.Names)
    {
        assert(local.nationality == module.nationality)

        let id:Module.ID = local.package.tree[local: module].id
        self.init(local: local, functions: functions)
        {
            if  let module:Atom<Module>.Position = 
                    $0.modules.find(id),
                    $0.exists(module.atom)
            {
                return .init(residency: $0, namespace: $0.package.tree[local: module])
            }
            else 
            {
                return nil
            }
        }
    }
    init(for article:Atom<Article>.Position, 
        local:__shared Package.Pinned, 
        functions:__shared Service.PublicFunction.Names)
    {
        assert(local.nationality == article.nationality)

        // the same article (by path name) may be assigned to different 
        // atoms in different branches
        let id:Article.ID = local.package.tree[local: article].id
        self.init(local: local, functions: functions)
        {
            if  let article:Atom<Article>.Position = 
                    $0.articles.find(id),
                    $0.exists(article.atom), 
                let namespace:Module = $0.load(local: article.culture)
            {
                return .init(residency: $0, namespace: namespace, 
                    article: $0.package.tree[local: article])
            }
            else 
            {
                return nil
            }
        }
    }
    init(for symbol:Atom<Symbol>.Position, 
        local:__shared Package.Pinned, 
        context:__shared Packages, 
        functions:__shared Service.PublicFunction.Names)
    {
        assert(local.nationality == symbol.nationality)

        let id:Symbol.ID = local.package.tree[local: symbol].id
        self.init(local: local, functions: functions)
        {
            if  let symbol:Atom<Symbol>.Position = 
                    $0.symbols.find(id),
                    $0.exists(symbol.atom),
                let metadata:Module.Metadata = 
                    $0.metadata(local: symbol.culture)
            {
                let context:LocalContext = .init(local: $0,
                    metadata: metadata, 
                    context: context)
                return context.local.address(of: symbol.atom, 
                    symbol: context.local.package.tree[local: symbol], 
                    context: context)
            }
            else 
            {
                return nil
            }

        }
    }
    init(for compound:Compound.Position, 
        local:__shared Package.Pinned,
        context:__shared Packages,
        functions:__shared Service.PublicFunction.Names)
    {
        assert(local.nationality == compound.nationality)
        
        let culture:Module.ID = local.package.tree[local: compound.culture].id
        let host:Symbol.ID = context[compound.host.nationality].tree[local: compound.host].id
        let base:Symbol.ID = context[compound.base.nationality].tree[local: compound.base].id

        self.init(local: local, functions: functions)
        {
            guard   let culture:Atom<Module>.Position = $0.modules.find(culture), 
                    let metadata:Module.Metadata = $0.metadata(local: culture.atom)
            else 
            {
                return nil 
            }

            let context:LocalContext = .init(local: $0,
                metadata: metadata, 
                context: context)
            
            if  let host:(position:Atom<Symbol>.Position, symbol:Symbol) = 
                    context.find(host, linked: metadata.dependencies),
                let base:(position:Atom<Symbol>.Position, symbol:Symbol) = 
                    context.find(base, linked: metadata.dependencies),
                // can’t think of why host would become equal to base, but hey, 
                // anything can happen...
                let compound:Compound = .init(
                    diacritic: .init(host: host.position.atom, culture: culture.atom), 
                    base: base.position.atom),
                    context.local.exists(compound) 
            {
                return context.local.address(of: compound, 
                    host: host.symbol, 
                    base: base.symbol, 
                    context: context)
            }
            else 
            {
                return nil
            }
        }
    }
}

extension Sequence<Evolution.Item> 
{
    var html:HTML.Element<Never> 
    {
        .ol(self.map 
        {
            let text:String = $0.label.description
            if let uri:String = $0.uri 
            {
                return .li(.a(text, attributes: [.href(uri)]))
            }
            else 
            {
                return .li(.span(text), attributes: [.class("current")])
            }
        })
    }
}
extension Evolution.Newer 
{
    var html:HTML.Element<Never> 
    {
        .div(.div(.p()), .div(.p(
                .init(escaped: "There’s a "),
                .a("newer version", attributes: [.href(self.uri)]),
                .init(escaped: " of this documentation available."))), 
            attributes: [.class("notice extinct")])
    }
}
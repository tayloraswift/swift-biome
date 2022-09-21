import HTML 
import DOM

struct _ReferenceCache 
{
    struct ArticleReference 
    {
        let metadata:Article.Metadata
        let uri:String

        var headline:Article.Headline 
        {
            self.metadata.headline
        }
    }
    struct PackageReference 
    {
        let name:Package.ID 
        let uri:String
    }
    struct ModuleReference 
    {
        let name:Module.ID 
        let uri:String
    }
    struct AtomicReference 
    {
        let community:Community 
        let shape:Symbol.Shape<PluralPosition<Symbol>>?
        let namespace:Atom<Module>
        let path:Path
        let uri:String 

        var name:String 
        {
            self.path.last
        }
    }
    // struct CompoundReference 
    // {
    //     let uri:String 
    // }

    let functions:Service.PublicFunction.Names

    mutating 
    func load(_ article:Atom<Article>, context:Package.Context) throws -> ArticleReference
    {
        fatalError("unimplemented")
    }
    mutating 
    func load(_ symbol:Atom<Symbol>, context:Package.Context) throws -> AtomicReference
    {
        fatalError("unimplemented")
    }
    mutating 
    func load(_ symbol:PluralPosition<Symbol>, context:Package.Context) -> AtomicReference 
    {
        fatalError("unimplemented")
    }

    mutating 
    func load(_ module:Atom<Module>, context:Package.Context) throws -> ModuleReference
    {
        fatalError("unimplemented")
    }

    func load(_ package:Package.Index, context:Package.Context) throws -> PackageReference
    {
        if let pinned:Package.Pinned = context[package]
        {
            return .init(name: pinned.package.id, 
                uri: pinned.address().uri(functions: self.functions).description)
        }
        else 
        {
            fatalError("unimplemented")
        }
    }

    mutating 
    func community(of symbol:Atom<Symbol>, context:Package.Context) throws -> Community
    {
        fatalError("unimplemented")
    }
    mutating 
    func name(of module:Atom<Module>, context:Package.Context) throws -> Module.ID 
    {
        fatalError("unimplemented")
    }

    mutating 
    func uri(of composite:Composite, context:Package.Context) throws -> String
    {
        fatalError("unimplemented")
    }
    mutating 
    func uri(of compound:Compound, context:Package.Context) throws -> String
    {
        fatalError("unimplemented")
    }
}
extension _ReferenceCache 
{
    mutating 
    func link(_ prose:DOM.Flattened<GlobalLink.Presentation>, context:Package.Context) 
        throws -> HTML.Element<Never> 
    {
        let utf8:[UInt8] = try prose.rendered
        {
            try self.expand($0, context: context).node.rendered(as: [UInt8].self)
        }
        return .init(node: .value(.init(escaped: utf8)))
    }
    private mutating 
    func expand(_ link:GlobalLink.Presentation, context:Package.Context) 
        throws -> HTML.Element<Never> 
    {
        switch link 
        {
        case .composite(let composite, visible: let visible):
            return try self.expand(composite, count: visible, context: context)
        
        case .article(let article):
            let article:ArticleReference = try self.load(article, context: context)
            let display:HTML.Element<Never> = .init(escaped: article.headline.formatted)
            return .cite(.a(display, attributes: [.href(article.uri)])) 
        
        case .module(let module):
            let module:ModuleReference = try self.load(module, context: context)
            return .code(.a(module.name.string, attributes: [.href(module.uri)]))
        
        case .package(let package):
            let package:PackageReference = try self.load(package, context: context)
            return .code(.a(package.name.string, attributes: [.href(package.uri)]))
        }
    }
    private mutating 
    func expand(_ link:Composite, count:Int, context:Package.Context) 
        throws -> HTML.Element<Never>
    {
        var current:AtomicReference = try self.load(link.base, context: context)
        var crumbs:[HTML.Element<Never>] = []
            crumbs.reserveCapacity(count)
        
        if  let compound:Compound = link.compound
        {
            let uri:String = try self.uri(of: compound, context: context)
            crumbs.append(.a(current.name, attributes: [.href(uri)]))
            current = try self.load(compound.host, context: context)
        }
        while crumbs.count < count 
        {
            if !crumbs.isEmpty 
            {
                crumbs.append(.init(escaped: "."))
            }

            crumbs.append(.a(current.name, attributes: [.href(current.uri)]))

            if let next:PluralPosition<Symbol> = current.shape?.target 
            {
                current = self.load(next, context: context)
            }
            else if crumbs.count < count 
            {
                let module:ModuleReference = try self.load(current.namespace, context: context)
                crumbs.append(.init(escaped: "."))
                crumbs.append(.a(module.name.string, attributes: [.href(module.uri)]))
                break 
            }
            else 
            {
                break 
            }
        }
        return .code(crumbs.reversed())
    }
}
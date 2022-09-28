import HTML 
import DOM

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
struct SymbolReference 
{
    let shape:Symbol.Shape<Atom<Symbol>.Position>?
    let display:Symbol.Display
    let namespace:Atom<Module>
    let uri:String 

    var name:String 
    {
        self.display.name
    }
    var path:Path 
    {
        self.display.path
    }
    var community:Community 
    {
        self.display.community
    }
}

extension PackageReference 
{
    var html:HTML.Element<Never> 
    {
        .a(self.name.string, attributes: [.href(self.uri)])
    }
}
extension ModuleReference 
{
    var html:HTML.Element<Never> 
    {
        .a(self.name.string, attributes: [.href(self.uri)])
    }
}
extension ArticleReference 
{
    var html:HTML.Element<Never> 
    {
        return .a(.init(escaped: self.headline.formatted), attributes: [.href(self.uri)])
    }
}

struct SymbolReferenceError:Error
{
    let key:Atom<Symbol>

    init(_ key:Atom<Symbol>)
    {
        self.key = key
    }
}

struct ReferenceCache 
{
    private 
    var articles:[Atom<Article>: ArticleReference]
    private 
    var symbols:[Atom<Symbol>: SymbolReference]
    private 
    var modules:[Atom<Module>: ModuleReference]
    private 
    var uris:[Compound: String]
    let functions:Service.PublicFunction.Names

    init(functions:Service.PublicFunction.Names)
    {
        self.functions = functions 
        self.articles = [:]
        self.symbols = [:]
        self.modules = [:]
        self.uris = [:]
    }

    private mutating
    func miss(_ key:Atom<Module>, module:Module, address:Address) -> ModuleReference
    {
        let reference:ModuleReference = .init(name: module.id, 
            uri: address.uri(functions: self.functions).description)
        self.modules[key] = reference 
        return reference
    }
    private mutating
    func miss(_ key:Atom<Symbol>, symbol:Symbol, address:Address) -> SymbolReference
    {
        let reference:SymbolReference = .init(shape: symbol.shape, display: symbol.display, 
            namespace: symbol.namespace, 
            uri: address.uri(functions: self.functions).description)
        self.symbols[key] = reference 
        return reference
    }
    private mutating
    func miss(_ key:Atom<Article>, metadata:Article.Metadata, address:Address) -> ArticleReference
    {
        let reference:ArticleReference = .init(metadata: metadata, 
            uri: address.uri(functions: self.functions).description)
        self.articles[key] = reference 
        return reference
    }
}

extension ReferenceCache 
{
    mutating 
    func load(_ key:Atom<Symbol>.Position, context:some PackageContext) throws -> SymbolReference
    {
        if  let cached:SymbolReference = self.symbols[key.atom]
        {
            return cached
        }
        if  let pinned:Package.Pinned = context[key.nationality]
        {
            let symbol:Symbol = pinned.package.tree[local: key]
            if  let address:Address = pinned.address(of: key.atom, symbol: symbol, 
                    context: context)
            {
                return self.miss(key.atom, symbol: symbol, address: address)
            }
        }
        fatalError("unimplemented")
    }
    mutating 
    func load(_ key:Atom<Symbol>, context:some PackageContext) throws -> SymbolReference
    {
        if  let cached:SymbolReference = self.symbols[key]
        {
            return cached
        }
        if  let pinned:Package.Pinned = context[key.nationality],
            let symbol:Symbol = pinned.load(local: key), 
            let address:Address = pinned.address(of: key, symbol: symbol, 
                    context: context)
        {
            return self.miss(key, symbol: symbol, address: address)
        }
        else 
        {
            fatalError("unimplemented")
        }
    }
}
extension ReferenceCache 
{
    mutating 
    func load(_ key:Atom<Module>.Position, context:some PackageContext) throws -> ModuleReference
    {
        if  let cached:ModuleReference = self.modules[key.atom]
        {
            return cached
        }
        if  let pinned:Package.Pinned = context[key.nationality]
        {
            let module:Module = pinned.package.tree[local: key]
            return self.miss(key.atom, module: module, address: .init(residency: pinned, 
                namespace: module))
        }
        else 
        {
            fatalError("unimplemented")
        }
    }
    mutating 
    func load(_ key:Atom<Module>, context:some PackageContext) throws -> ModuleReference
    {
        if  let cached:ModuleReference = self.modules[key]
        {
            return cached
        }
        if  let pinned:Package.Pinned = context[key.nationality],
            let module:Module = pinned.load(local: key)
        {
            return self.miss(key, module: module, address: .init(residency: pinned, 
                namespace: module))
        }
        else 
        {
            fatalError("unimplemented")
        }
    }
}
extension ReferenceCache 
{
    mutating 
    func load(_ key:Atom<Article>, context:some PackageContext) throws -> ArticleReference
    {
        if  let cached:ArticleReference = self.articles[key]
        {
            return cached
        }
        if  let pinned:Package.Pinned = context[key.nationality],
            let namespace:Module = pinned.load(local: key.culture),
            let article:Article = pinned.load(local: key), 
            let metadata:Article.Metadata = pinned.metadata(local: key)
        {
            return self.miss(key, metadata: metadata, address: .init(residency: pinned, 
                namespace: namespace, 
                article: article))
        }
        else 
        {
            fatalError("unimplemented")
        }
    }
}
extension ReferenceCache
{
    func load(_ package:Package.Index, context:some PackageContext) throws -> PackageReference
    {
        if let pinned:Package.Pinned = context[package]
        {
            let address:Address = .init(residency: pinned)
            return .init(name: pinned.package.id, 
                uri: address.uri(functions: self.functions).description)
        }
        else 
        {
            fatalError("unimplemented")
        }
    }
}

extension ReferenceCache 
{
    mutating
    func uri(of composite:Composite, context:some PackageContext) throws -> String
    {
        if let compound:Compound = composite.compound 
        {
            return try self.uri(of: compound, context: context)
        }
        else 
        {
            return try self.load(composite.base, context: context).uri
        }
    }
    mutating
    func uri(of compound:Compound, context:some PackageContext) throws -> String
    {
        if      let cached:String = self.uris[compound]
        {
            return cached 
        }
        // unfortunately, we do not cache the loaded components, because 
        // we do not want to compute any uris we might not use.
        else if let address:Address = context[compound.nationality]?.address(of: compound, 
                    context: context)
        {
            let uri:String = address.uri(functions: self.functions).description
            self.uris[compound] = uri
            return uri 
        }
        else 
        {
            fatalError("unimplemented")
        }
    }
}

extension ReferenceCache 
{
    mutating 
    func link(_ prose:DOM.Flattened<GlobalLink.Presentation>, context:some PackageContext) 
        throws -> [UInt8]?
    {
        prose.isEmpty ? nil : try prose.rendered
        {
            try self.expand($0, context: context).node.rendered(as: [UInt8].self)
        }
    }

    private mutating 
    func expand(_ link:GlobalLink.Presentation, context:some PackageContext) 
        throws -> HTML.Element<Never> 
    {
        switch link 
        {
        case .composite(let composite, visible: let visible):
            return try self.expand(composite, count: visible, context: context)
        
        case .article(let article):
            return .cite(try self.load(article, context: context).html) 
        
        case .module(let module):
            return .code(try self.load(module, context: context).html)
        
        case .package(let package):
            return .code(try self.load(package, context: context).html)
        }
    }
    private mutating 
    func expand(_ link:Composite, count:Int, context:some PackageContext) 
        throws -> HTML.Element<Never>
    {
        var current:SymbolReference = try self.load(link.base, context: context)
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

            if let next:Atom<Symbol>.Position = current.shape?.target 
            {
                current = try self.load(next, context: context)
            }
            else if crumbs.count < count 
            {
                let module:ModuleReference = try self.load(current.namespace, context: context)
                crumbs.append(.init(escaped: "."))
                crumbs.append(module.html)
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
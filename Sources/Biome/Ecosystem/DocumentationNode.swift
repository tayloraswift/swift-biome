import DOM
import HTML
import SymbolGraphs
import URI

typealias DocumentationNode = Documentation<Article.Template<Ecosystem.Link>, Symbol.Index>

extension Ecosystem 
{
    func compile(comments:[Symbol.Index: Documentation<String, Symbol.Index>],
        extensions:[[String: Extension]],
        articles:[[Article.Index: Extension]], 
        scopes:[Module.Scope], 
        pins:Package.Pins)
        -> [Index: DocumentationNode]
    {
        //  build lexical scopes for each module culture. 
        //  we can store entire packages in the lenses because this method 
        //  is non-mutating!
        let pinned:Package.Pinned = .init(self[pins.local.package], 
            at: pins.local.version)
        let peripherals:[[Index: Extension]] = 
            self.resolveBindings(of: extensions, 
                articles: articles, 
                pinned: pinned,
                scopes: scopes)
        // add upstream lenses 
        let lenses:[[Package.Pinned]] = scopes.map 
        {
            let dependencies:Set<Package.Index> = .init($0.filter.lazy.map(\.package))
            var lenses:[Package.Pinned] = []
                lenses.reserveCapacity(dependencies.count)
            for package:Package.Index in dependencies where package != $0.culture.package
            {
                lenses.append(self[package].pinned(pins))
            }
            lenses.append(pinned)
            return lenses
        }
        return self.compile(comments: comments, 
            peripherals: peripherals, 
            lenses: lenses, 
            scopes: scopes)
    }
}

extension Ecosystem
{
    private 
    func resolveBindings(of extensions:[[String: Extension]], 
        articles:[[Article.Index: Extension]],
        pinned:Package.Pinned,
        scopes:[Module.Scope]) 
        -> [[Index: Extension]]
    {
        zip(scopes, zip(articles, extensions)).map
        {
            let (       scope, ( articles,                           extensions)):
                (Module.Scope, ([Article.Index: Extension], [String: Extension])) = $0
            
            var bindings:[Index: Extension] = [:]
                bindings.reserveCapacity(articles.count + extensions.count)
            for (index, article):(Article.Index, Extension) in articles 
            {
                bindings[.article(index)] = article
            }
            for (binding, article):(String, Extension) in extensions
            {
                guard let binding:Index = self.resolveWithRedirect(binding: binding, 
                    pinned: pinned,
                    scope: scope)
                else 
                {
                    print("ignored extension '\(article.metadata.path as Any)' with unknown binding ``\(binding)``")
                    continue 
                }
                // TODO: emit warning for colliding extensions
                bindings[binding] = article 
            }
            return bindings
        }
    }
    private 
    func resolveWithRedirect(binding string:String, 
        pinned:Package.Pinned,
        scope:Module.Scope) 
        -> Index?
    {
        if  let uri:URI = try? .init(relative: string), 
            let link:Link = try? self.resolveWithRedirect(
                visibleLink: uri,
                lenses: [pinned], 
                scope: scope)
        {
            return link.target
        }
        else 
        {
            return nil 
        }
    }
}
extension Ecosystem
{
    private 
    func compile(comments:[Symbol.Index: Documentation<String, Symbol.Index>], 
        peripherals:[[Index: Extension]], 
        lenses:[[Package.Pinned]],
        scopes:[Module.Scope])
        -> [Index: DocumentationNode]
    {
        var documentation:[Index: DocumentationNode] = 
            .init(minimumCapacity: comments.count + peripherals.reduce(0) { $0 + $1.count })
        self.compile(&documentation,
            peripherals: peripherals, 
            lenses: lenses, 
            scopes: scopes)
        self.compile(&documentation,
            comments: comments, 
            lenses: lenses, 
            scopes: scopes)
        return documentation
    }
    private
    func compile(_ documentation:inout [Index: DocumentationNode], 
        peripherals:[[Index: Extension]], 
        lenses:[[Package.Pinned]],
        scopes:[Module.Scope])
    {
        let swift:Package.Index? = self.packages.indices[.swift]
        for ((lenses, scope), assigned):(([Package.Pinned], Module.Scope), [Index: Extension]) in 
            zip(zip(lenses, scopes), peripherals)
        {
            for (target, article):(Index, Extension) in assigned
            {
                documentation[target] = .extends(nil, with: self.compile(article, 
                    lenses: lenses, 
                    scope: scope.import(article.metadata.imports, swift: swift), 
                    nest: self.nest(target)))
            } 
        }
    }
    private
    func compile(_ documentation:inout [Index: DocumentationNode], 
        comments:[Symbol.Index: Documentation<String, Symbol.Index>], 
        lenses:[[Package.Pinned]],
        scopes:[Module.Scope])
    {
        let swift:Package.Index? = self.packages.indices[.swift]
        // need to turn the lexica into something we can select from a flattened 
        // comments dictionary 
        let contexts:[Module.Index: Int] = 
            .init(uniqueKeysWithValues: zip(scopes.lazy.map(\.culture), scopes.indices))
        for (symbol, comment):(Symbol.Index, Documentation<String, Symbol.Index>) in comments
        {
            guard let context:Int = contexts[symbol.module] 
            else 
            {
                fatalError("unreachable")
            }
            let target:Index = .symbol(symbol)
            switch comment 
            {
            case .inherits(let origin): 
                documentation[target] = .inherits(origin)
            
            case .extends(let origin, with: let comment):
                let comment:Extension = .init(markdown: comment)
                
                documentation[target] = .extends(origin, with: self.compile(comment, 
                    lenses: lenses[context], 
                    scope: scopes[context].import(comment.metadata.imports, swift: swift), 
                    nest: self.nest(target)))
            }
        } 
    }
    private 
    func compile(_ article:Extension, 
        lenses:[Package.Pinned],
        scope:Module.Scope,
        nest:Symbol.Nest?)
        -> Article.Template<Link>
    {
        article.render().transform 
        {
            (string:String, errors:inout [Error]) -> DOM.Substitution<Link, [UInt8]> in 
            
            let doclink:Bool
            let suffix:Substring 
            if  let start:String.Index = 
                    string.index(string.startIndex, offsetBy: 4, limitedBy: string.endIndex), 
                string[..<start] == "doc:"
            {
                doclink = true 
                suffix = string[start...]
            }
            else 
            {
                doclink = false 
                suffix = string[...]
            }
            do 
            {
                // must attempt to parse absolute first, otherwise 
                // '/foo' will parse to ["", "foo"]
                let resolved:Link?
                // global "doc:" links not supported yet
                if !doclink, let uri:URI = try? .init(absolute: suffix)
                {
                    resolved = try self.resolveWithRedirect(globalLink: uri, 
                        lenses: lenses, 
                        scope: scope)
                }
                else 
                {
                    let uri:URI = try .init(relative: suffix)
                    
                    resolved = try self.resolveWithRedirect(visibleLink: uri, nest: nest,
                        doclink: doclink,
                        lenses: lenses, 
                        scope: scope)
                }
                if let resolved:Link
                {
                    return .key(resolved)
                }
                else 
                {
                    throw Packages.SelectionError.none
                }
            }
            catch let error 
            {
                errors.append(LinkResolutionError.init(link: string, error: error))
                return .segment(HTML.Element<Never>.code(string).node.rendered(as: [UInt8].self))
            }
        }
    }
    private 
    func nest(_ target:Index) -> Symbol.Nest?
    {
        guard case .composite(let composite) = target 
        else 
        {
            return nil 
        }
        if  let host:Symbol.Index = composite.host 
        {
            let host:Symbol = self[host]
            return .init(namespace: host.namespace, prefix: [String].init(host.path))
        }
        else 
        {
            return self[composite.base].nest
        }
    }
    
    private 
    func resolveWithRedirect(globalLink uri:URI, 
        lenses:[Package.Pinned], 
        scope:Module.Scope) 
        throws -> Link? 
    {
        let (global, fold):([String], Int) = uri.path.normalized
        
        guard   let destination:Package.ID = global.first.map(Package.ID.init(_:)), 
                let destination:Package.Index = self.packages.indices[destination]
        else 
        {
            return nil 
        }
        guard let link:Symbol.Link = 
            try? .init(path: (global.dropFirst(), fold), query: uri.query ?? [])
        else 
        {
            return nil
        }
        guard let namespace:Module.ID = (link.first?.string).map(Module.ID.init(_:)) 
        else 
        {
            return .init(.package(destination), visible: 1)
        }
        guard let namespace:Module.Index = self[destination].modules.indices[namespace]
        else 
        {
            return nil
        }
        guard let implicit:Symbol.Link = link.suffix 
        else 
        {
            return .init(.module(namespace), visible: 1)
        }
        
        guard   let pins:Package.Pins = self.packages.localize(destination: destination, 
                    lens: implicit.query.lens), 
                let route:Route.Key = self.stems[namespace, implicit.revealed],
                let selection:Packages.Selection = self.packages.selectExtantWithRedirect(route, 
                    lens: .init(self[pins.local.package], at: pins.local.version), 
                    by: implicit.disambiguator)?.selection
        else 
        {
            return nil
        }
        return .init(.composite(try selection.composite()), visible: implicit.count)
    }
    private 
    func resolveWithRedirect(visibleLink uri:URI, 
        nest:Symbol.Nest? = nil, 
        doclink:Bool = false, 
        lenses:[Package.Pinned],
        scope:Module.Scope) 
        throws -> Link? 
    {
        let (path, fold):([String], Int) = uri.path.normalized 
        if  doclink,  
            let article:Path = .init(path),
            let article:Article.Index = 
                self[scope.culture.package].articles.indices[.init(self[scope.culture].id, article)]
        {
            return .init(.article(article), visible: path.endIndex - fold)
        }
        let expression:Symbol.Link = 
            try .init(path: (path, fold), query: uri.query ?? [])
        if      let index:Index = try self.resolve(
                    visibleLink: expression.revealed, nest: nest, 
                    lenses: lenses, 
                    scope: scope)
        {
            return .init(index, visible: expression.count)
        }
        else if let outed:Symbol.Link = expression.revealed.outed,
                let index:Index = try self.resolve(
                    visibleLink: outed, nest: nest, 
                    lenses: lenses, 
                    scope: scope)
        {
            return .init(index, visible: expression.count)
        }
        else 
        {
            return nil
        }
    }
    private 
    func resolve(visibleLink link:Symbol.Link, 
        nest:Symbol.Nest? = nil, 
        lenses:[Package.Pinned],
        scope:Module.Scope) 
        throws -> Index? 
    {
        //  check if the first component refers to a module. it can be the same 
        //  as its own culture, or one of its dependencies. 
        if  let namespace:Module.ID = (link.first?.string).map(Module.ID.init(_:)), 
            let namespace:Module.Index = scope[namespace]
        {
            guard let implicit:Symbol.Link = link.suffix 
            else 
            {
                return .module(namespace)
            }
            if let local:Index = try self.resolve(relativeLink: implicit, 
                    namespace: namespace, 
                    lenses: lenses,
                    scope: scope)
            {
                return local
            }
        }
        if  let nest:Symbol.Nest,
            let relative:Index = try self.resolve(relativeLink: link, 
                namespace: nest.namespace, 
                prefix: nest.prefix, 
                lenses: lenses, 
                scope: scope)
        {
            return relative
        }
        // primary culture takes precedence
        if  let absolute:Index = try self.resolve(relativeLink: link, 
                namespace: scope.culture, 
                lenses: lenses, 
                scope: scope) 
        {
            return absolute
        }
        var imported:Index? = nil 
        for namespace:Module.Index in scope.filter where namespace != scope.culture 
        {
            if  let absolute:Index = try self.resolve(relativeLink: link, 
                    namespace: namespace, 
                    lenses: lenses, 
                    scope: scope) 
            {
                if case nil = imported 
                {
                    imported = absolute
                }
                else 
                {
                    // name collision
                    return nil 
                }
            }
        }
        return imported
    }
    private 
    func resolve(relativeLink link:Symbol.Link, 
        namespace:Module.Index, 
        prefix:[String] = [], 
        lenses:[Package.Pinned], 
        scope:Module.Scope) 
        throws -> Index?
    {
        guard let route:Route.Key = self.stems[namespace, prefix, link]
        else 
        {
            return nil
        }
        let disambiguator:Symbol.Disambiguator = link.disambiguator
        let selection:Packages.Selection? = self.packages.selectExtant(route, 
            lenses: lenses)
        {
            scope.contains($0.culture) && self.packages.filter($0, by: disambiguator)
        }
        return (try selection?.composite()).map(Index.composite(_:))
    }
}

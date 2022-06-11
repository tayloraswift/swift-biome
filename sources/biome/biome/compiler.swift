/* enum Documentation:Equatable
{
    case template(Article.Template<Link>)
    case shared(Package.Index, Keyframe<Self>.Buffer.Index)
} */

extension Ecosystem 
{
    func compileDocumentation(for culture:Package.Index,
        extensions:[[String: Extension]],
        articles:[[Article.Index: Extension]], 
        comments:[Symbol.Index: String], 
        scopes:[Module.Scope], 
        pins:Package.Pins,
        keys:Route.Keys)
        -> [Index: Article.Template<Link>]
    {
        //  build lexical scopes for each module culture. 
        //  we can store entire packages in the lenses because this method 
        //  is non-mutating!
        let lens:Lexicon.Lens = .init(self[culture])
        var lexica:[Lexicon] = scopes.map 
        {
            .init(keys: keys, namespaces: $0, lenses: [lens])
        }
        
        let peripherals:[[Index: Extension]] = 
            self.resolveBindings(of: extensions, articles: articles, lexica: lexica)
        
        // add upstream lenses 
        for lexicon:Int in lexica.indices 
        {
            let packages:Set<Package.Index> = lexica[lexicon].namespaces.packages()
            lexica[lexicon].lenses.append(contentsOf: packages.map
            {
                .init(self[$0], at: pins[$0])
            })
        }
        
        return self.compile(comments: comments, peripherals: peripherals, lexica: lexica)
    }
    
    private 
    func resolveBindings(of extensions:[[String: Extension]], 
        articles:[[Article.Index: Extension]],
        lexica:[Lexicon]) 
        -> [[Index: Extension]]
    {
        zip(lexica, zip(articles, extensions)).map
        {
            let (lexicon, ( articles,                          extensions)):
                (Lexicon, ([Article.Index: Extension], [String: Extension])) = $0
            
            var bindings:[Index: Extension] = [:]
                bindings.reserveCapacity(articles.count + extensions.count)
            for (index, article):(Article.Index, Extension) in articles 
            {
                bindings[.article(index)] = article
            }
            for (binding, article):(String, Extension) in extensions
            {
                guard let binding:Index = self.resolve(binding: binding, lexicon: lexicon)
                else 
                {
                    fatalError("unimplemented")
                }
                // TODO: emit warning for colliding extensions
                bindings[binding] = article 
            }
            return bindings
        }
    }
    
    private 
    func compile(comments:[Symbol.Index: String], 
        peripherals:[[Index: Extension]], 
        lexica:[Lexicon])
        -> [Index: Article.Template<Link>]
    {
        let comments:[Index: Article.Template<Link>] = 
            self.compile(comments: comments, lexica: lexica)
        let peripherals:[Index: Article.Template<Link>] = 
            self.compile(peripherals: peripherals, lexica: lexica)
        return comments.merging(peripherals) { $1 }
    }
    private
    func compile(comments:[Symbol.Index: String], lexica:[Lexicon])
        -> [Index: Article.Template<Link>]
    {
        //  always import the standard library
        let implicit:Set<Module.Index> = self.standardLibrary
        // need to turn the lexica into something we can select from a flattened 
        // comments dictionary 
        let lexica:[Module.Index: Lexicon] = 
            .init(uniqueKeysWithValues: lexica.map { ($0.namespaces.culture, $0) })
        
        var templates:[Index: Article.Template<Link>] = 
            .init(minimumCapacity: comments.count)
        for (symbol, comment):(Symbol.Index, String) in comments
        {
            guard let lexicon:Lexicon = lexica[symbol.module] 
            else 
            {
                fatalError("unreachable")
            }
            
            let nest:Symbol.Nest? = self[symbol].nest
            let comment:Extension = .init(markdown: comment)
            let imports:Set<Module.Index> = 
                implicit.union(lexicon.resolve(imports: comment.metadata.imports))
            let unresolved:Article.Template<String> = comment.render()
            let resolved:Article.Template<Link> = unresolved.map 
            {
                self.resolve(link: $0, 
                    lexicon: lexicon, 
                    imports: imports, 
                    nest: nest)
            }
            templates[.symbol(symbol)] = resolved
        } 
        return templates
    }
    private
    func compile(peripherals:[[Index: Extension]], lexica:[Lexicon])
        -> [Index: Article.Template<Link>]
    {
        //  always import the standard library
        let implicit:Set<Module.Index> = self.standardLibrary
        
        var templates:[Index: Article.Template<Link>] = 
            .init(minimumCapacity: peripherals.reduce(0) { $0 + $1.count })
        for (lexicon, assigned):(Lexicon, [Index: Extension]) in zip(lexica, peripherals)
        {
            for (target, article):(Index, Extension) in assigned
            {
                let nest:Symbol.Nest? = self.nest(target)
                let imports:Set<Module.Index> = 
                    implicit.union(lexicon.resolve(imports: article.metadata.imports))
                let unresolved:Article.Template<String> = article.render()
                let resolved:Article.Template<Link> = unresolved.map 
                {
                    self.resolve(link: $0, 
                        lexicon: lexicon, 
                        imports: imports, 
                        nest: nest)
                }
                templates[target] = resolved
            } 
        }
        return templates
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
}

extension Ecosystem 
{
    mutating 
    func updateDocumentation(in culture:Package.Index, 
        compiled:[Index: Article.Template<Link>],
        hints:[Symbol.Index: Symbol.Index], 
        pins:Package.Pins)
    {
        self[culture].updateDocumentation(compiled)
        self[culture].spreadDocumentation(self.recruitMigrants(in: culture, 
            sponsors: compiled, 
            hints: hints, 
            pins: pins))
    }
    // `culture` parameter not strictly needed, but we use it to make sure 
    // that ``generateRhetoric(graphs:scopes:)`` did not return ``hints``
    // about other packages
    private 
    func recruitMigrants(in culture:Package.Index,
        sponsors:[Index: Article.Template<Link>],
        hints:[Symbol.Index: Symbol.Index],
        pins:Package.Pins) 
        -> [Symbol.Index: Article.Template<Link>]
    {
        var migrants:[Symbol.Index: Article.Template<Link>] = [:]
        for (member, sponsor):(Symbol.Index, Symbol.Index) in hints
            where !sponsors.keys.contains(.symbol(member))
        {
            assert(member.module.package == culture)
            // if a symbol did not have documentation of its own, 
            // check if it has a sponsor. article templates are copy-on-write 
            // types, so this will not (eagarly) copy storage
            if  let template:Article.Template<Link> = sponsors[.symbol(sponsor)] 
            {
                migrants[member] = template
            }
            // note: empty doccomments are omitted from the template buffer
            else if culture != sponsor.module.package,
                let template:Article.Template<Link> = 
                self.template(for: sponsor, at: pins[sponsor.module.package])
            {
                migrants[member] = template
            }
        }
        return migrants
    }
}

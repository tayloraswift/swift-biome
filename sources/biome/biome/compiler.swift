enum Documentation:Equatable
{
    case template(Article.Template<Link>)
    case shared(Keyframe<Self>.Buffer.Index)
}

extension Ecosystem 
{
    func compileDocumentation(for culture:Package.Index,
        extensions:[[String: Extension]],
        articles:[[Article.Index: Extension]], 
        comments:[Symbol.Index: String], 
        scopes:[Module.Scope], 
        pins:Package.Pins,
        keys:Route.Keys)
        -> [Index: Documentation]
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
        -> [Index: Documentation]
    {
        let comments:[Index: Documentation] = 
            self.compile(comments: comments, lexica: lexica)
        let peripherals:[Index: Documentation] = 
            self.compile(peripherals: peripherals, lexica: lexica)
        return comments.merging(peripherals) { $1 }
    }
    private
    func compile(comments:[Symbol.Index: String], lexica:[Lexicon])
        -> [Index: Documentation]
    {
        //  always import the standard library
        let implicit:Set<Module.Index> = self.standardLibrary
        // need to turn the lexica into something we can select from a flattened 
        // comments dictionary 
        let lexica:[Module.Index: Lexicon] = 
            .init(uniqueKeysWithValues: lexica.map { ($0.namespaces.culture, $0) })
        
        var documentation:[Index: Documentation] = 
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
            documentation[.symbol(symbol)] = .template(resolved)
        } 
        return documentation
    }
    private
    func compile(peripherals:[[Index: Extension]], lexica:[Lexicon])
        -> [Index: Documentation]
    {
        //  always import the standard library
        let implicit:Set<Module.Index> = self.standardLibrary
        
        var documentation:[Index: Documentation] = 
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
                documentation[target] = .template(resolved)
            } 
        }
        return documentation
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
        compiled:[Index: Documentation],
        hints:[Symbol.Index: Symbol.Index], 
        pins:Package.Pins)
    {
        let sponsors:[Symbol.Index: Keyframe<Documentation>.Buffer.Index] = 
            self[culture].updateDocumentation(compiled)
        let migrants:[Symbol.Index: Keyframe<Documentation>.Buffer.Index] = 
            self.recruitMigrants(in: culture, 
                sponsors: _move(sponsors), 
                hints: hints, 
                pins: pins)
        self[culture].distributeDocumentation(_move(migrants))
    }
    // `culture` parameter not strictly needed, but we use it to make sure 
    // that ``generateRhetoric(graphs:scopes:)`` did not return ``hints``
    // about other packages
    private 
    func recruitMigrants(in culture:Package.Index,
        sponsors:[Symbol.Index: Keyframe<Documentation>.Buffer.Index],
        hints:[Symbol.Index: Symbol.Index],
        pins:Package.Pins) 
        -> [Symbol.Index: Keyframe<Documentation>.Buffer.Index]
    {
        var migrants:[Symbol.Index: Keyframe<Documentation>.Buffer.Index] = [:]
        for (member, sponsor):(Symbol.Index, Symbol.Index) in hints
            where !sponsors.keys.contains(member)
        {
            assert(member.module.package == culture)
            // if a symbol did not have documentation of its own, 
            // check if it has a sponsor 
            if let sponsor:Keyframe<Documentation>.Buffer.Index = sponsors[sponsor]
            {
                migrants[member] = sponsor 
            }
            else if culture != sponsor.module.package
            {
                // note: empty doccomments are omitted from the documentation buffer
                guard let sponsor:Keyframe<Documentation>.Buffer.Index = 
                    self[sponsor.module.package].documentation(forLocal: sponsor, 
                        at: pins[sponsor.module.package])
                else 
                {
                    continue 
                }
                migrants[member] = sponsor
            }
        }
        return migrants
    }
}

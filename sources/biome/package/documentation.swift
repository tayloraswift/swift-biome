enum Documentation:Equatable
{
    case template(Article.Template<Link>)
    case shared(Keyframe<Self>.Buffer.Index)
}

extension Package 
{    
    func documentation(ecosystem:Ecosystem, 
        comments:[[Symbol.Index: String]], 
        extras:Extras, 
        scopes:[Module.Scope], 
        keys:Route.Keys)
        -> [Link.Target: Documentation]
    {
        //  build lexical scopes for each module culture. 
        //  initialize a single-lens lexicon for each culture. it should contain 
        //  *all* our available namespaces, but only *one* lens.
        var lexica:[Lexicon] = scopes.map 
        {
            .init(keys: keys, namespaces: $0, lenses: [self.lens])
        }
        let extras:[[Link.Target: Extension]] = extras.assigned(lexica: lexica)
        {
            self[$0] ?? ecosystem[$0]
        }
        // add upstream lenses 
        for lexicon:Int in lexica.indices 
        {
            let lenses:[Lexicon.Lens] = lexica[lexicon].namespaces.packages().map
            {
                ecosystem[$0].lens
            }
            lexica[lexicon].lenses.append(contentsOf: lenses)
        }
        
        let comments:[Link.Target: Documentation] = 
            self.documentation(ecosystem: ecosystem, lexica: lexica, comments: comments)
        let assigned:[Link.Target: Documentation] = 
            self.documentation(ecosystem: ecosystem, lexica: lexica, assigned: extras)
        return comments.merging(assigned) { $1 }
    }
    private 
    func standardLibrary(ecosystem:Ecosystem) -> Set<Module.Index>
    {
        guard let package:Self = self.id == .swift ? self : ecosystem[.swift] 
        else 
        {
            return []
        }
        return .init(package.modules.indices.values)
    }
    private 
    func documentation(ecosystem:Ecosystem, lexica:[Lexicon], comments:[[Symbol.Index: String]])
        -> [Link.Target: Documentation]
    {
        //  always import the standard library
        let standardLibrary:Set<Module.Index> = self.standardLibrary(ecosystem: ecosystem)
        
        var documentation:[Link.Target: Documentation] = [:]
            documentation.reserveCapacity(comments.reduce(0) { $0 + $1.count })
        for (lexicon, comments):(Lexicon, [Symbol.Index: String]) in zip(lexica, comments)
        {
            for (symbol, comment):(Symbol.Index, String) in comments
            {
                let nest:Symbol.Nest? = self[local: symbol].nest
                let comment:Extension = .init(markdown: comment)
                let imports:Set<Module.Index> = 
                    standardLibrary.union(lexicon.resolve(imports: comment.metadata.imports))
                let unresolved:Article.Template<String> = comment.render()
                let resolved:Article.Template<Link> = unresolved.map 
                {
                    lexicon.resolve(expression: $0, imports: imports, nest: nest)
                    {
                        self[$0] ?? ecosystem[$0]
                    }
                }
                documentation[.symbol(symbol)] = .template(resolved)
            } 
        }
        return documentation
    }
    private 
    func documentation(ecosystem:Ecosystem, lexica:[Lexicon], assigned:[[Link.Target: Extension]])
        -> [Link.Target: Documentation]
    {
        //  always import the standard library
        let standardLibrary:Set<Module.Index> = self.standardLibrary(ecosystem: ecosystem)
        
        var documentation:[Link.Target: Documentation] = [:]
            documentation.reserveCapacity(assigned.reduce(0) { $0 + $1.count })
        for (lexicon, assigned):(Lexicon, [Link.Target: Extension]) in zip(lexica, assigned)
        {
            for (target, article):(Link.Target, Extension) in assigned
            {
                let nest:Symbol.Nest? = self.nest(ecosystem: ecosystem, local: target)
                let imports:Set<Module.Index> = 
                    standardLibrary.union(lexicon.resolve(imports: article.metadata.imports))
                let unresolved:Article.Template<String> = article.render()
                let resolved:Article.Template<Link> = unresolved.map 
                {
                    lexicon.resolve(expression: $0, imports: imports, nest: nest)
                    {
                        self[$0] ?? ecosystem[$0]
                    }
                }
                documentation[target] = .template(resolved)
            } 
        }
        return documentation
    }
    private 
    func nest(ecosystem:Ecosystem, local target:Link.Target) -> Symbol.Nest?
    {
        guard case .composite(let composite) = target 
        else 
        {
            return nil 
        }
        if  let victim:Symbol.Index = composite.victim 
        {
            let victim:Symbol = self[victim] ?? ecosystem[victim]
            return .init(namespace: victim.namespace, prefix: [String].init(victim.path))
        }
        else 
        {
            return self[local: composite.base].nest
        }
    }
}

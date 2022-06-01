enum Documentation:Equatable
{
    case template(Article.Template<Link>)
    case shared(Keyframe<Self>.Buffer.Index)
}

extension Ecosystem 
{
    func resolveBindings(of extensions:[[String: Extension]], 
        articles:[[Article.Index: Extension]],
        lexica:[Lexicon]) 
        -> [[Link.Target: Extension]]
    {
        zip(lexica, zip(articles, extensions)).map
        {
            let (lexicon, ( articles,                          extensions)):
                (Lexicon, ([Article.Index: Extension], [String: Extension])) = $0
            
            var bindings:[Link.Target: Extension] = [:]
                bindings.reserveCapacity(articles.count + extensions.count)
            for (index, article):(Article.Index, Extension) in articles 
            {
                bindings[.article(index)] = article
            }
            for (binding, article):(String, Extension) in extensions
            {
                guard let link:Link.Expression = try? Link.Expression.init(relative: binding)
                else 
                {
                    print("warning: ignored article with invalid binding '\(binding)'")
                    continue 
                }
                switch lexicon.resolve(visible: link.reference, { self[$0] })
                {
                case .many(_)?, nil: 
                    fatalError("unimplemented")
                case .one(let unique)?:
                    // TODO: emit warning for colliding extensions
                    bindings[unique] = article 
                }
            }
            return bindings
        }
    }
    
    func compile(comments:[Symbol.Index: String], 
        peripherals:[[Link.Target: Extension]], 
        lexica:[Lexicon])
        -> [Link.Target: Documentation]
    {
        let comments:[Link.Target: Documentation] = 
            self.compile(comments: comments, lexica: lexica)
        let peripherals:[Link.Target: Documentation] = 
            self.compile(peripherals: peripherals, lexica: lexica)
        return comments.merging(peripherals) { $1 }
    }
    private
    func compile(comments:[Symbol.Index: String], lexica:[Lexicon])
        -> [Link.Target: Documentation]
    {
        //  always import the standard library
        let implicit:Set<Module.Index> = self.standardLibrary
        // need to turn the lexica into something we can select from a flattened 
        // comments dictionary 
        let lexica:[Module.Index: Lexicon] = 
            .init(uniqueKeysWithValues: lexica.map { ($0.namespaces.culture, $0) })
        
        var documentation:[Link.Target: Documentation] = 
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
                self.resolve(string: $0, imports: imports, nest: nest, lexicon: lexicon)
            }
            documentation[.symbol(symbol)] = .template(resolved)
        } 
        return documentation
    }
    private
    func compile(peripherals:[[Link.Target: Extension]], lexica:[Lexicon])
        -> [Link.Target: Documentation]
    {
        //  always import the standard library
        let implicit:Set<Module.Index> = self.standardLibrary
        
        var documentation:[Link.Target: Documentation] = 
            .init(minimumCapacity: peripherals.reduce(0) { $0 + $1.count })
        for (lexicon, assigned):(Lexicon, [Link.Target: Extension]) in zip(lexica, peripherals)
        {
            for (target, article):(Link.Target, Extension) in assigned
            {
                let nest:Symbol.Nest? = self.nest(target)
                let imports:Set<Module.Index> = 
                    implicit.union(lexicon.resolve(imports: article.metadata.imports))
                let unresolved:Article.Template<String> = article.render()
                let resolved:Article.Template<Link> = unresolved.map 
                {
                    self.resolve(string: $0, imports: imports, nest: nest, lexicon: lexicon)
                }
                documentation[target] = .template(resolved)
            } 
        }
        return documentation
    }
    private 
    func nest(_ target:Link.Target) -> Symbol.Nest?
    {
        guard case .composite(let composite) = target 
        else 
        {
            return nil 
        }
        if  let victim:Symbol.Index = composite.victim 
        {
            let victim:Symbol = self[victim]
            return .init(namespace: victim.namespace, prefix: [String].init(victim.path))
        }
        else 
        {
            return self[composite.base].nest
        }
    }
    private 
    func resolve(string:String, imports:Set<Module.Index>, nest:Symbol.Nest?, lexicon:Lexicon) 
        -> Link
    {
        // must attempt to parse absolute first, otherwise 
        // '/foo' will parse to ["", "foo"]
        let resolution:Link.Resolution?
        let visible:Int
        if let absolute:Link.Expression = try? .init(absolute: string)
        {
            visible = absolute.visible
            resolution = self.resolve(global: absolute.reference, lexicon: lexicon)
        }
        else if let relative:Link.Expression = try? .init(relative: string)
        {
            visible = relative.visible
            resolution = lexicon.resolve(
                visible: relative.reference, 
                imports: imports, 
                nest: nest)
            {
                self[$0]
            }
        }
        else 
        {
            print("unknown", string)
            return .fallback(string)
        }
        
        switch resolution
        {
        case nil:
            print("FAILURE", string)
            if let nest:Symbol.Nest = nest 
            {
                print("note: location is \(nest)")
            }
            
        case .one(.composite(let composite))?:
            /* if let victim:Symbol.Index = composite.victim 
            {
                print("SUCCESS", string, "->", try dereference(composite.base), 
                    "for", try dereference(victim))
            }
            else 
            {
                print("SUCCESS", string, "->", try dereference(composite.base))
            } */
            return .target(.composite(composite), visible: visible)
        
        case .one(let target)?: 
            //print("SUCCESS", string, "-> (unavailable)")
            return .target(target, visible: visible)
        
        case .many(let possibilities)?: 
            print("AMBIGUOUS", string)
            for (i, possibility):(Int, Link.Target) in possibilities.enumerated()
            {
                switch possibility 
                {
                case .composite(let composite):
                    if let victim:Symbol.Index = composite.victim 
                    {
                        print("\(i).", self[composite.base], "for", self[victim])
                    }
                    else 
                    {
                        print("\(i).", self[composite.base])
                    }
                default: 
                    print("\(i). (unavailable)")
                }
            }
            if let nest:Symbol.Nest = nest 
            {
                print("note: location is \(nest)")
            }
        }
        return .fallback(string)
    }
    private 
    func resolve<Tail>(global link:Link.Reference<Tail>, lexicon:Lexicon)
        -> Link.Resolution?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        guard   let nation:Package.ID = link.nation, 
                let nation:Package = self[nation]
        else 
        {
            return nil 
        }
        
        let qualified:Link.Reference<Tail.SubSequence> = link.dropFirst()
        
        guard let namespace:Module.ID = qualified.namespace 
        else 
        {
            return .one(.package(nation.index))
        }
        // if the global path starts with a package/namespace that 
        // matches one of our dependencies, treat it like a qualified 
        // reference. 
        if  case nil = qualified.query.lens, 
            let namespace:Module.Index = lexicon.namespaces[namespace], 
                namespace.package == nation.index
        {
            return lexicon.resolve(namespace, [], qualified.dropFirst()) { self[$0] }
        }
        else 
        {
            guard let namespace:Module.Index = nation.modules.indices[namespace]
            else 
            {
                return nil 
            }
            let implicit:Link.Reference<Tail.SubSequence> = _move(qualified).dropFirst()
            guard let path:Path = .init(implicit.path.compactMap(\.prefix))
            else 
            {
                return .one(.module(namespace))
            }
            guard let route:Route = lexicon.keys[namespace, path, implicit.orientation]
            else 
            {
                return nil
            }
            // determine which package contains the actual symbol documentation; 
            // it may be different from the nation 
            let lens:Lexicon.Lens 
            if case let (culture, departure)? = implicit.query.lens, 
                let culture:Package = self[culture]
            {
                lens = culture.lens(departure) 
            }
            else 
            {
                // TODO: enable parsing explicit version 
                lens = nation.lens(nil) 
            }
            return lens.resolve(route, disambiguation: implicit.disambiguation) { self[$0] }
        }
    } 
}

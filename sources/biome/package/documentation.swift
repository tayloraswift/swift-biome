enum Documentation:Equatable
{
    case template(Article.Template<Link>)
    case shared(Keyframe<Self>.Buffer.Index)
}

extension Package 
{    
    func documentation(ecosystem:Ecosystem, 
        comments:[Symbol.Index: String], 
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
            self.documentation(comments, lexica: lexica, ecosystem: ecosystem)
        let assigned:[Link.Target: Documentation] = 
            self.documentation(extras, lexica: lexica, ecosystem: ecosystem)
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
    func documentation(_ comments:[Symbol.Index: String], lexica:[Lexicon], ecosystem:Ecosystem)
        -> [Link.Target: Documentation]
    {
        //  always import the standard library
        let standardLibrary:Set<Module.Index> = self.standardLibrary(ecosystem: ecosystem)
        // need to turn the lexica into something we can select from a flattened 
        // comments dictionary 
        let lexica:[Module.Index: Lexicon] = 
            .init(uniqueKeysWithValues: lexica.map { ($0.namespaces.culture, $0) })
        
        var documentation:[Link.Target: Documentation] = [:]
            documentation.reserveCapacity(comments.count)
        for (symbol, comment):(Symbol.Index, String) in comments
        {
            guard let lexicon:Lexicon = lexica[symbol.module] 
            else 
            {
                fatalError("unreachable")
            }
            
            let nest:Symbol.Nest? = self[local: symbol].nest
            let comment:Extension = .init(markdown: comment)
            let imports:Set<Module.Index> = 
                standardLibrary.union(lexicon.resolve(imports: comment.metadata.imports))
            let unresolved:Article.Template<String> = comment.render()
            let resolved:Article.Template<Link> = unresolved.map 
            {
                self.resolve(string: $0, imports: imports, nest: nest, 
                    lexicon: lexicon, ecosystem: ecosystem)
            }
            documentation[.symbol(symbol)] = .template(resolved)
        } 
        return documentation
    }
    private 
    func documentation(_ assigned:[[Link.Target: Extension]], lexica:[Lexicon], ecosystem:Ecosystem)
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
                let nest:Symbol.Nest? = self.nest(local: target, ecosystem: ecosystem)
                let imports:Set<Module.Index> = 
                    standardLibrary.union(lexicon.resolve(imports: article.metadata.imports))
                let unresolved:Article.Template<String> = article.render()
                let resolved:Article.Template<Link> = unresolved.map 
                {
                    self.resolve(string: $0, imports: imports, nest: nest, 
                        lexicon: lexicon, ecosystem: ecosystem)
                }
                documentation[target] = .template(resolved)
            } 
        }
        return documentation
    }
    private 
    func nest(local target:Link.Target, ecosystem:Ecosystem) -> Symbol.Nest?
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
    private 
    func resolve(string:String, imports:Set<Module.Index>, nest:Symbol.Nest?, 
        lexicon:Lexicon, ecosystem:Ecosystem) 
        -> Link
    {
        // must attempt to parse absolute first, otherwise 
        // '/foo' will parse to ["", "foo"]
        let resolution:Link.Resolution?
        let visible:Int
        if let absolute:Link.Expression = try? .init(absolute: string)
        {
            visible = absolute.visible
            resolution = self.resolve(global: absolute.reference, 
                lexicon: lexicon, ecosystem: ecosystem)
        }
        else if let relative:Link.Expression = try? .init(relative: string)
        {
            visible = relative.visible
            resolution = lexicon.resolve(
                visible: relative.reference, 
                imports: imports, 
                nest: nest)
            {
                self[$0] ?? ecosystem[$0]
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
                        print("\(i).", self[composite.base] ?? ecosystem[composite.base], 
                            "for", self[victim] ?? ecosystem[victim])
                    }
                    else 
                    {
                        print("\(i).", self[composite.base] ?? ecosystem[composite.base])
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
    func resolve<Path>(global link:Link.Reference<Path>, lexicon:Lexicon, ecosystem:Ecosystem)
        -> Link.Resolution?
        where Path:BidirectionalCollection, Path.Element == Link.Component
    {
        guard   let nation:Package.ID = link.nation, 
                let nation:Self = self.id == nation ? self : ecosystem[nation]
        else 
        {
            return nil 
        }
        
        let qualified:Link.Reference<Path.SubSequence> = link.dropFirst()
        
        guard let namespace:Module.ID = qualified.namespace 
        else 
        {
            return .one(.package(nation.index))
        }
        // if the global path starts with a package/namespace that 
        // matches one of our dependencies, treat it like a qualified 
        // reference. 
        if  case nil = qualified.query.culture, 
            let namespace:Module.Index = lexicon.namespaces[namespace], 
                namespace.package == nation.index, 
            let resolution:Link.Resolution = 
                lexicon.resolve(namespace, [], qualified.dropFirst(), 
                {
                    self[$0] ?? ecosystem[$0]
                })
        {
            return resolution
        }
        guard let namespace:Module.Index = nation.modules.indices[namespace]
        else 
        {
            return nil 
        }
        // determine which package contains the actual symbol documentation; 
        // it may be different from the nation 
        let lens:Lexicon.Lens 
        if  let culture:ID = link.query.culture, 
            let culture:Self = self.id == culture ? self : ecosystem[culture]
        {
            lens = culture.lens 
        }
        else 
        {
            lens = nation.lens 
        }
        return lens.resolve(namespace, qualified.dropFirst(), keys: lexicon.keys)
        {
            self[$0] ?? ecosystem[$0]
        }
        
        /* let local:Link.Reference<Path.SubSequence>
        let nation:Self, 
            implicit:Bool
        if  let package:ID = link.nation, 
            let package:Self = self.id == package ? self : ecosystem[package]
        {
            implicit = false
            nation = package 
            local = link.dropFirst()
        }
        else if let swift:Self = ecosystem[.swift]
        {
            implicit = true
            nation = swift
            local = link[...]
        }
        else 
        {
            return nil
        }
        guard let namespace:Module.ID = local.namespace 
        else 
        {
            return implicit ? nil : .one(.package(nation.index))
        } */
    } 
}

struct ModuleInterface 
{
    struct LookupError:Error 
    {
        let index:Int 

        init(_ index:Int)
        {
            self.index = index
        }
    }

    struct Abstractor<Element>:RandomAccessCollection where Element:BranchElement 
    {
        private 
        var table:[Tree.Position<Element>?]
        private 
        let updated:Int

        var startIndex:Int
        {
            self.table.startIndex
        }
        var endIndex:Int
        {
            self.table.endIndex
        }
        subscript(index:Int) -> Tree.Position<Element>? 
        {
            _read 
            {
                yield  self.table[index]
            }
            _modify
            {
                yield &self.table[index]
            }
        }

        init(_ table:__owned [Tree.Position<Element>?])
        {
            self.table = table 
            self.updated = self.table.endIndex
        }

        func citizens(culture:Element.Culture) -> Citizens<Element> 
        {
            .init(self.table.prefix(upTo: self.updated), culture: culture)
        }

        mutating 
        func extend(over identifiers:[Element.ID], 
            by find:(Element.ID) throws -> Tree.Position<Element>?) rethrows 
        {
            for external:Element.ID in identifiers.suffix(from: self.table.endIndex)
            {
                self.table.append(try find(external))
            }
        }
    }

    struct Citizens<Element>:RandomAccessCollection where Element:BranchElement
    {
        private 
        let table:ArraySlice<Tree.Position<Element>?>
        let culture:Element.Culture

        init(_ table:ArraySlice<Tree.Position<Element>?>, culture:Element.Culture)
        {
            self.table = table 
            self.culture = culture 
        }

        var startIndex:Int
        {
            self.table.startIndex
        }
        var endIndex:Int
        {
            self.table.endIndex
        }
        // the `prefix` excludes symbols that were once in the current package, 
        // but for whatever reason were left out of the current version of the 
        // current package.
        // the `flatMap` excludes symbols that are not native to the current 
        // module. this happens sometimes due to member inference.
        subscript(index:Int) -> Tree.Position<Element>? 
        {
            self.table[index].flatMap { self.culture == $0.contemporary.culture ? $0 : nil }
        }
    }

    let namespaces:Namespaces 
    var articles:Abstractor<Article>
    var symbols:Abstractor<Symbol>

    // this does not belong here! once AOT article rendering lands in the `SymbolGraphs` module, 
    // we can get rid of it
    let _cachedMarkdown:[Extension]

    var citizenArticles:Citizens<Article> 
    {
        self.articles.citizens(culture: self.culture)
    }
    var citizenSymbols:Citizens<Symbol> 
    {
        self.symbols.citizens(culture: self.culture)
    }
    var nationality:Package.Index
    {
        self.namespaces.nationality
    }
    var culture:Branch.Position<Module> 
    {
        self.namespaces.culture 
    }
    var pins:[Package.Index: Version] 
    {
        self.namespaces.pins
    }

    init(namespaces:__owned Namespaces, 
        _extensions:__owned [Extension],
        articles:__owned Abstractor<Article>,
        symbols:__owned Abstractor<Symbol>)
    {
        self.namespaces = namespaces
        self.articles = articles
        self.symbols = symbols

        self._cachedMarkdown = _extensions
    }
}
extension ModuleInterface.Abstractor<Symbol> 
{
    func translate(edges:[SymbolGraph.Edge<Int>], context:SurfaceBuilder.Context) 
        -> (beliefs:[Belief], errors:[ModuleInterface.LookupError])
    {
        var errors:[ModuleInterface.LookupError] = []
        // if we have `n` edges, we will get between `n` and `2n` beliefs
        var beliefs:[Belief] = []
            beliefs.reserveCapacity(edges.count)
        for edge:SymbolGraph.Edge<Int> in edges
        {
            let opaque:SymbolGraph.Edge<Tree.Position<Symbol>>
            do 
            {
                opaque = try edge.map 
                {
                    if let position:Tree.Position<Symbol> = self[$0]
                    {
                        return position
                    }
                    else 
                    {
                        throw ModuleInterface.LookupError.init($0)
                    }
                }
            } 
            catch let error 
            {
                errors.append(error as! ModuleInterface.LookupError)
                continue
            }
            switch opaque.beliefs(
                source: context[global: opaque.source].community, 
                target: context[global: opaque.target].community)
            {
            case (let source?,  let target):
                beliefs.append(source)
                beliefs.append(target)
            case (nil,          let target):
                beliefs.append(target)
            }
        }
        return (beliefs, errors)
    }
}
extension SymbolGraph.Edge<Tree.Position<Symbol>>
{
    fileprivate
    func beliefs(source:Community, target:Community) -> (source:Belief?, target:Belief)
    {
        switch (source, self.source, is: self.relation, of: target, self.target) 
        {
        case    (.callable, let source, is: .feature, of: .concretetype, let target):
            return
                (
                    nil,
                    .init(target, .has(.feature(source)))
                )
        
        case    (.concretetype, let source, is: .member,    of: .concretetype,  let target), 
                (.typealias,    let source, is: .member,    of: .concretetype,  let target), 
                (.callable,     let source, is: .member,    of: .concretetype,  let target), 
                (.concretetype, let source, is: .member,    of: .protocol,      let target),
                (.typealias,    let source, is: .member,    of: .protocol,      let target),
                (.callable,     let source, is: .member,    of: .protocol,      let target):
            return 
                (
                    .init(source,  .is(.member(of: target))), 
                    .init(target, .has(.member(    source)))
                )
        
        case    (.concretetype, let source, is: .conformer(let conditions), of: .protocol, let target):
            return 
                (
                    .init(source, .has(.conformance(.init(target, where: conditions)))), 
                    .init(target, .has(  .conformer(.init(source, where: conditions))))
                )
         
        case    (.protocol, let source, is: .conformer([]), of: .protocol, let target):
            return 
                (
                    .init(source,  .is(.refinement(of: target))), 
                    .init(target, .has(.refinement(    source)))
                ) 
        
        case    (.class, let source, is: .subclass, of: .class, let target):
            return 
                (
                    .init(source,  .is(.subclass(of: target))), 
                    .init(target, .has(.subclass(    source)))
                ) 
         
        case    (.associatedtype,   let source, is: .override, of: .associatedtype, let target),
                (.callable,         let source, is: .override, of: .callable,       let target):
            return 
                (
                    .init(source,  .is(.override(of: target))), 
                    .init(target, .has(.override(    source)))
                ) 
         
        case    (.associatedtype,   let source, is:         .requirement, of: .protocol, let target),
                (.callable,         let source, is:         .requirement, of: .protocol, let target),
                (.associatedtype,   let source, is: .optionalRequirement, of: .protocol, let target),
                (.callable,         let source, is: .optionalRequirement, of: .protocol, let target):
            return 
                (
                    .init(source,  .is(.requirement(of: target))), 
                    .init(target,  .is(  .interface(of: source)))
                ) 
         
        case    (.callable, let source, is: .defaultImplementation, of: .callable, let target):
            return 
                (
                    .init(source,  .is(.implementation(of: target))), 
                    .init(target, .has(.implementation(    source)))
                ) 
        
        default:
            fatalError("unimplemented")
        }
    }
}

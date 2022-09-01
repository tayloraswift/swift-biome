struct _Abstractor
{
    struct LookupError:Error 
    {
        let index:Int 

        init(_ index:Int)
        {
            self.index = index
        }
    }
    // the `prefix` excludes symbols that were once in the current package, 
    // but for whatever reason were left out of the current version of the 
    // current package.
    // the `compactMap` excludes symbols that are not native to the current 
    // module. this happens sometimes due to member inference.
    struct UpdatedSymbols:RandomAccessCollection
    {
        let culture:Module.Index 
        let symbols:ArraySlice<Tree.Position<Symbol>?>

        var startIndex:Int
        {
            self.symbols.startIndex
        }
        var endIndex:Int
        {
            self.symbols.endIndex
        }
        subscript(index:Int) -> Tree.Position<Symbol>? 
        {
            self.symbols[index].flatMap { $0.contemporary.module == self.culture ? $0 : nil }
        }
    }

    let culture:Module.Index 
    private 
    let updated:Int
    private(set)
    var symbols:[Tree.Position<Symbol>?], 
        articles:[Tree.Position<Article>?]

    var updatedSymbols:UpdatedSymbols 
    {
        .init(culture: self.culture, symbols: self.symbols[..<self.updated])
    }
    
    @available(*, deprecated)
    var startIndex:Int
    {
        self.symbols.startIndex
    }
    @available(*, deprecated)
    var endIndex:Int
    {
        self.symbols.endIndex
    }
    @available(*, deprecated)
    subscript(index:Int) -> Tree.Position<Symbol>? 
    {
        _read 
        {
            yield  self.symbols[index]
        }
        _modify
        {
            yield &self.symbols[index]
        }
    }

    init(symbols:__owned [Tree.Position<Symbol>?], 
        articles:[Tree.Position<Article>?], 
        culture:Module.Index)
    {
        self.culture = culture 
        self.updated = symbols.endIndex
        self.symbols = symbols
        self.articles = articles
    }

    mutating 
    func extend(over identifiers:[Symbol.ID], 
        by find:(Symbol.ID) throws -> Tree.Position<Symbol>?) rethrows 
    {
        for external:Symbol.ID in identifiers.suffix(from: self.symbols.endIndex)
        {
            self.symbols.append(try find(external))
        }
    }

    func translate(edges:[SymbolGraph.Edge<Int>], context:Packages) 
        -> (beliefs:[Belief], errors:[LookupError])
    {
        var errors:[LookupError] = []
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
                    if let position:Tree.Position<Symbol> = self.symbols[$0]
                    {
                        return position
                    }
                    else 
                    {
                        throw LookupError.init($0)
                    }
                }
            } 
            catch let error 
            {
                errors.append(error as! LookupError)
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

@available(*, deprecated)
struct Abstractor:RandomAccessCollection, MutableCollection
{
    // the `prefix` excludes symbols that were once in the current package, 
    // but for whatever reason were left out of the current version of the 
    // current package.
    // the `compactMap` excludes symbols that are not native to the current 
    // module. this happens sometimes due to member inference.
    struct Updates:RandomAccessCollection
    {
        let culture:Module.Index 
        let indices:ArraySlice<Symbol.Index?>

        var startIndex:Int
        {
            self.indices.startIndex
        }
        var endIndex:Int
        {
            self.indices.endIndex
        }
        subscript(index:Int) -> Symbol.Index? 
        {
            self.indices[index].flatMap { $0.module == self.culture ? $0 : nil }
        }
    }

    let culture:Module.Index 
    private 
    let updated:Int
    private
    var indices:[Symbol.Index?]

    var updates:Updates 
    {
        .init(culture: self.culture, indices: self.indices[..<self.updated])
    }
    
    var startIndex:Int
    {
        self.indices.startIndex
    }
    var endIndex:Int
    {
        self.indices.endIndex
    }
    subscript(index:Int) -> Symbol.Index? 
    {
        _read 
        {
            yield  self.indices[index]
        }
        _modify
        {
            yield &self.indices[index]
        }
    }

    fileprivate 
    init(culture:Module.Index, indices:[Symbol.Index?], updated:Int)
    {
        self.culture = culture 
        self.updated = updated
        self.indices = indices 
    }
}
extension SymbolGraph 
{
    func abstractor(context:Packages, scope:Module.Scope) -> Abstractor
    {
        // includes the current package 
        let packages:Set<Package.Index> = .init(scope.filter.lazy.map(\.package))
        let lenses:[[Symbol.ID: Symbol.Index]] = packages.map 
        { 
            context[$0].symbols.indices 
        }
        let indices:[Symbol.Index?] = self.identifiers.map 
        {
            var match:Symbol.Index? = nil
            for lens:[Symbol.ID: Symbol.Index] in lenses
            {
                guard let index:Symbol.Index = lens[$0], scope.contains(index.module)
                else 
                {
                    continue 
                }
                if case nil = match 
                {
                    match = index
                }
                else 
                {
                    // sanity check: ensure none of the remaining lenses contains 
                    // a colliding key 
                    fatalError("colliding symbol identifiers in search space")
                }
            }
            return match
        }
        return .init(culture: scope.culture, indices: indices, updated: self.vertices.endIndex)
    }
}
extension SymbolGraph 
{
    func declarations(abstractor:Abstractor) -> [(Symbol.Index, Declaration<Symbol.Index>)]
    {
        zip(abstractor.updates, self.vertices).compactMap
        {
            guard case (let symbol?, let vertex) = $0
            else 
            {
                return nil 
            }
            let declaration:Declaration<Symbol.Index> = vertex.declaration.flatMap 
            {
                if  let target:Symbol.Index = abstractor[$0]
                {
                    return target 
                }
                // ignore warnings related to c-language symbols 
                let id:Symbol.ID = self.identifiers[$0]
                if case .swift = id.language 
                {
                    let error:Symbol.LookupError = .unknownID(id)
                    print("warning: \(error) (in declaration for symbol '\(vertex.path)')")
                }
                return nil
            }
            return (symbol, declaration)
        }
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

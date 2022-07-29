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
extension SymbolGraph
{
    func statements(abstractor:Abstractor, context:Packages) -> [Symbol.Statement]
    {
        var errors:[Symbol.LookupError] = []
        // if we have `n` edges, we will get between `n` and `2n` statements
        var rhetoric:[Symbol.Statement] = []
            rhetoric.reserveCapacity(self.edges.count)
        for edge:Edge<Int> in self.edges
        {
            let indexed:Edge<Symbol.Index>
            do 
            {
                indexed = try edge.map 
                {
                    if let index:Symbol.Index = abstractor[$0]
                    {
                        return index
                    }
                    else 
                    {
                        throw Symbol.LookupError.unknownID(self.identifiers[$0])
                    }
                }
            } 
            catch let error 
            {
                errors.append(error as! Symbol.LookupError)
                continue
            }
            switch indexed.statements(
                source: context[indexed.source].community, 
                target: context[indexed.target].community)
            {
            case (let source?,  let target):
                rhetoric.append(source)
                rhetoric.append(target)
            case (nil,          let target):
                rhetoric.append(target)
            }
        }

        if !errors.isEmpty 
        {
            print("warning: dropped \(errors.count) edges from '\(self.id)'")
        }

        return rhetoric
    }
}

extension SymbolGraph.Edge where Target == Symbol.Index
{
    fileprivate
    func statements(source:Community, target:Community) 
        -> (source:Symbol.Statement?, target:Symbol.Statement)
    {
        switch (source, self.source, is: self.relation, of: target, self.target) 
        {
        case    (.callable, let source, is: .feature, of: .concretetype, let target):
            return
                (
                    nil,
                    (target, .has(.feature(source)))
                )
        
        case    (.concretetype, let source, is: .member,    of: .concretetype,  let target), 
                (.typealias,    let source, is: .member,    of: .concretetype,  let target), 
                (.callable,     let source, is: .member,    of: .concretetype,  let target), 
                (.concretetype, let source, is: .member,    of: .protocol,      let target),
                (.typealias,    let source, is: .member,    of: .protocol,      let target),
                (.callable,     let source, is: .member,    of: .protocol,      let target):
            return 
                (
                    (source,  .is(.member(of: target))), 
                    (target, .has(.member(    source)))
                )
        
        case    (.concretetype, let source, is: .conformer(let conditions), of: .protocol, let target):
            return 
                (
                    (source, .has(.conformance(.init(target, where: conditions)))), 
                    (target, .has(  .conformer(.init(source, where: conditions))))
                )
         
        case    (.protocol, let source, is: .conformer([]), of: .protocol, let target):
            return 
                (
                    (source,  .is(.refinement(of: target))), 
                    (target, .has(.refinement(    source)))
                ) 
        
        case    (.class, let source, is: .subclass, of: .class, let target):
            return 
                (
                    (source,  .is(.subclass(of: target))), 
                    (target, .has(.subclass(    source)))
                ) 
         
        case    (.associatedtype,   let source, is: .override, of: .associatedtype, let target),
                (.callable,         let source, is: .override, of: .callable,       let target):
            return 
                (
                    (source,  .is(.override(of: target))), 
                    (target, .has(.override(    source)))
                ) 
         
        case    (.associatedtype,   let source, is:         .requirement, of: .protocol, let target),
                (.callable,         let source, is:         .requirement, of: .protocol, let target),
                (.associatedtype,   let source, is: .optionalRequirement, of: .protocol, let target),
                (.callable,         let source, is: .optionalRequirement, of: .protocol, let target):
            return 
                (
                    (source,  .is(.requirement(of: target))), 
                    (target,  .is(  .interface(of: source)))
                ) 
         
        case    (.callable, let source, is: .defaultImplementation, of: .callable, let target):
            return 
                (
                    (source,  .is(.implementation(of: target))), 
                    (target, .has(.implementation(    source)))
                ) 
        
        default:
            fatalError("unimplemented")
        }
    }
}

import Notebook

/* struct Node 
{
    let index:Symbol.Index 
    
    var availability:Availability 
    var signature:Notebook<Fragment.Color, Never> 
    var declaration:Notebook<Fragment.Color, Symbol.ID> 
    var generics:[Generic] 
    var genericConstraints:[Generic.Constraint<Symbol.ID>] 
    var extensionConstraints:[Generic.Constraint<Symbol.ID>] 
    
    var legality:Declaration.Legality
    var relationships:[Symbol.Relationship]
    
    init(index:Symbol.Index, vertex:Vertex)
    {
        self.index = index 
        
        self.availability = vertex.availability
        self.signature = vertex.signature
        self.declaration = vertex.declaration
        self.generics = vertex.generics
        self.genericConstraints = vertex.genericConstraints
        self.extensionConstraints = vertex.extensionConstraints
        
        self.legality = .documented(vertex.comment)
        self.relationships = []
    }
} */

extension Symbol
{
    struct Frame:Equatable
    {
        // signatures and declarations can change without disturbing the symbol identifier, 
        // since they contain information that is not part of ABI.
        let signature:Notebook<Fragment.Color, Never>
        let declaration:Notebook<Fragment.Color, Symbol.Index>
        // generic parameter *names* are not part of ABI.
        let generics:[Generic]
        // these *might* be version-independent, but right now we are storing generic 
        // parameter/associatedtype names
        let genericConstraints:[Generic.Constraint<Symbol.Index>]
        let extensionConstraints:[Generic.Constraint<Symbol.Index>]
        let availability:Availability
        
        init(_ vertex:Vertex.Frame, given scope:Scope) throws 
        {
            self.availability   = vertex.availability 
            self.generics       = vertex.generics
            self.signature      = vertex.signature
            // even with mythical symbol inference, it is still possible or 
            // declarations to reference non-existent USRs, e.g. 'ss14_UnicodeParserP8EncodingQa'
            // (Swift._UnicodeParser.Encoding)
            self.declaration = vertex.declaration.compactMap 
            {
                do 
                {
                    return try scope.index(of: $0)
                }
                catch let error 
                {
                    print("warning: \(error)")
                    return nil 
                }
            }
            // self.declaration    = try node.vertex.declaration.map(scope.index(of:))
            self.genericConstraints = try vertex.genericConstraints.map
            {
                try $0.map(scope.index(of:))
            }
            self.extensionConstraints = try vertex.extensionConstraints.map
            {
                try $0.map(scope.index(of:))
            }
            
            //self.relationships = try .init(validating: node.relationships, as: node.vertex.color)
        }
    }
    
    struct Buffer 
    {
        private 
        var module:
        (
            buffer:[Module], 
            indices:[Module.ID: Module.Index]
        ) 
        private 
        var symbols:[Symbol], 
            indices:[ID: Index]
        private 
        var frames:Keyframe<Frame>.Buffer 
        // documentation:Keyframe<Void>.Buffer,
        private 
        var relationships:Keyframe<Relationships>.Buffer
        
        var lens:[ID: Index]
        {
            self.indices
        }
        
        init() 
        {
            self.symbols = []
            self.indices = [:]
            self.module.buffer = []
            self.module.indices = [:]
            
            self.frames = .init()
            // self.documentation = .init()
            self.relationships = .init()
        }
        
        private(set)
        subscript(local module:Module.Index) -> Module 
        {
            _read 
            {
                yield  self.module.buffer[module.offset]
            }
            _modify
            {
                yield &self.module.buffer[module.offset]
            }
        }
        private(set)
        subscript(local symbol:Symbol.Index) -> Symbol
        {
            _read 
            {
                yield  self.symbols[symbol.offset]
            }
            _modify
            {
                yield &self.symbols[symbol.offset]
            }
        }
        
        func index(of module:Module.ID) -> Module.Index? 
        {
            self.module.indices[module] 
        }
        
        mutating 
        func create(module:Module.ID, in package:Package.Index) -> Module.Index 
        {
            if  let index:Module.Index = self.module.indices[module]
            {
                return index 
            }
            else 
            {
                // create records for modules if they do not yet exist 
                let index:Module.Index = .init(package, offset: self.module.buffer.endIndex)
                self.module.buffer.append(.init(id: module, index: index))
                self.module.indices[module] = index
                return index 
            }
        }

        mutating 
        func extend(with graph:Module.Graph, of culture:Module.Index, 
            upstream:Scope, namespaces:[Module.ID: Module.Index], 
            paths:inout PathTable) throws -> [Index: Vertex.Frame]
        {            
            var updates:[Index: Vertex.Frame] = [:]
            try self.extend(with: graph.core.vertices, of: culture, namespace: culture, 
                upstream: upstream, paths: &paths)
            {
                updates[$0] = $1
            }
            
            for colony:Module.Subgraph in graph.colonies 
            {
                guard let namespace:Module.Index = namespaces[colony.namespace]
                else 
                {
                    throw Module.ResolutionError.dependency(colony.namespace, of: graph.core.namespace)
                }
                try self.extend(with: colony.vertices, of: culture, namespace: namespace, 
                    upstream: upstream, paths: &paths)
                {
                    updates[$0] = $1
                }
            }
            // a vertex is top-level if it has exactly one path component. 
            /* let toplevel:[Symbol.Index] = core.filter 
            {
                buffer.nodes[$0.offset].vertex.path.count == 1
            } */
            return updates
        }
        
        private mutating 
        func extend(with vertices:[(id:ID, vertex:Vertex)], 
            of culture:Module.Index, namespace:Module.Index, upstream:Scope, 
            paths:inout PathTable, update:(Index, Vertex.Frame) throws -> ()) throws 
        {
            let start:Int = self.symbols.endIndex
            for (id, vertex):(ID, Vertex) in vertices 
            {
                guard case nil = upstream[id]
                else 
                {
                    // usually happens because of inferred symbols. ignore.
                    continue 
                }
                if let index:Index = self.indices[id]
                {
                    // already have a symbol for this id, hopefully from a previous version. 
                    // we don’t know if it’s from a previous version because the 
                    // implementation of ``Module/Subgraph`` only enforces unique 
                    // identifiers on a module-wide (not package-wide) basis.
                    try update(index, vertex.frame)
                    continue 
                }
                
                let index:Index = .init(culture, offset: self.symbols.endIndex)
                
                if case _? = self.indices.updateValue(index, forKey: id)
                {
                    throw Symbol.CollisionError.init(id) 
                }
                
                try update(index, vertex.frame)
                
                let leaf:String = vertex.path[vertex.path.endIndex - 1]
                let stem:[String] = .init(vertex.path.dropLast())
                let symbol:Symbol = .init(id: id, 
                    key: .init(namespace, 
                              paths.register(components: stem), 
                        .init(paths.register(component:  leaf), orientation: vertex.color.orientation)), 
                    nest: stem, 
                    name: leaf, 
                    color: vertex.color)
                self.symbols.append(symbol)
            }
            let range:ColonialRange = .init(namespace: namespace, offsets: start ..< self.symbols.endIndex)
            self.module.buffer[culture.offset].matrix.append(range)
        }
        
        mutating 
        func update<S>(with vertices:S) throws 
            where S:Sequence, S.Element == (Scope, [Index: Vertex.Frame])
        {
            for (scope, updates):(Scope, [Index: Vertex.Frame]) in vertices
            {
                for (symbol, frame):(Index, Vertex.Frame) in updates 
                {
                    // we have to inline the ``subscript(local:)`` call due to 
                    // overlapping access
                    self.frames.update(head: &self.symbols[symbol.offset].latestFrame, 
                        with: try .init(frame, given: scope))
                }
            }
        }
        mutating 
        func update(with nodes:[Index: [Relationship]]) throws
        {
            for (symbol, relationships):(Index, [Relationship]) in nodes 
            {
                // we have to inline the ``subscript(local:)`` call due to 
                // overlapping access
                self.relationships.update(head: &self.symbols[symbol.offset].latestRelationships, 
                    with: try .init(validating: relationships, as: self[local: symbol].color))
            }
        }
        mutating 
        func update(with traits:[Index: [Trait]], from package:Package.Index)
        {
            for (symbol, traits):(Index, [Trait]) in traits 
            {
                self[local: symbol].update(traits: traits, from: package)
            }
        }
    }
}
extension Symbol 
{
    struct Tray 
    {
        private(set)
        var nodes:[Index: [Relationship]]
        
        init<Indices>(_ indices:Indices) where Indices:Sequence, Indices.Element == Symbol.Index 
        {
            self.nodes = .init(uniqueKeysWithValues: indices.map { ($0, []) })
        }
        
        mutating 
        func link(_ statement:Statement, of culture:Module.Index) 
            throws -> (subject:Index, has:Trait)?
        {
            switch statement.predicate
            {
            case  .is(let role):
                guard culture         == statement.subject.module
                else 
                {
                    throw RelationshipError.unauthorized(culture, says: statement.subject, is: role)
                }
            case .has(let trait):
                guard culture.package == statement.subject.module.package
                else 
                {
                    return (statement.subject, has: trait)
                }
            }
            
            if case _? = self.nodes[statement.subject]?.append(statement.predicate)
            {
                return nil
            }
            else 
            {
                fatalError("unreachable")
            }
        }
        
        /* mutating 
        func deduplicate(_ sponsored:Symbol.Index, against papers:String, from sponsor:Symbol.Index) 
            throws
        {
            switch self[sponsored]?.legality
            {
            case nil:
                // cannot sponsor symbols from another package (but symbols in 
                // another package can sponsor symbols in this package)
                
                // FIXME: we need to handle this error! it indicates that data is 
                // also being duplicated ELSEWHERE
                
                // throw Symbol.SponsorshipError.unauthorized(self.package, says: sponsored, isSponsoredBy: sponsor)
                break
            
            case .sponsored(by: sponsor):
                // documentation has already been de-deduplicated
                break 
            
            case .sponsored(by: let other): 
                throw Symbol.SponsorshipError.disputed(sponsored, isSponsoredBy: other, and: sponsor)
            
            case .undocumented?, .documented(papers)?:
                self.nodes[sponsored.offset].legality = .sponsored(by: sponsor)
            
            case .documented(_):
                // a small number of symbols using fakes are actually documented, 
                // and should not be deported. 
                // print("warning: recovered documentation for symbol \(self.nodes[sponsored.offset].vertex.path)")
                // print("> sponsor’s documentation:")
                // print(papers)
                // print("> alien’s documentation:")
                // print(recovered)
                // print("------------")
                break
            }
        } */
    }
}

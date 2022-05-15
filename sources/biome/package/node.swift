extension Package 
{
    struct Node 
    {
        var vertex:Vertex.Content
        var legality:Symbol.Legality
        var relationships:[Symbol.Relationship]
        
        fileprivate 
        init(_ vertex:Vertex)
        {
            self.vertex = vertex.content 
            self.legality = .documented(vertex.comment)
            self.relationships = []
        }
        fileprivate 
        init(protocol mythical:(name:String, id:Symbol.ID), members:[Symbol.Index])
        {
            let fragments:[Fragment] = 
            [
                .init("protocol",    color: .keywordText),
                .init(" ",           color: .text),
                .init(mythical.name, color: .identifier),
            ]
            self.vertex = .init(
                id:                     mythical.id,
                path:                  [mythical.name],
                color:                 .protocol, 
                availability:          .init(), 
                signature:             .init(fragments), 
                declaration:           .init(fragments), 
                generics:               [], 
                genericConstraints:     [], 
                extensionConstraints:   [])
            self.legality = .undocumented 
            self.relationships = members.map { .has(.member($0)) }
        }
    }
    struct NodeBuffer 
    {
        private 
        let package:Package.Index
        private(set) 
        var nodes:[Node]
        
        init(package:Package.Index)
        {
            self.nodes = []
            self.package = package 
        }
                
        subscript(index:Symbol.Index) -> Node?
        {
            self.package == index.module.package ? self.nodes[index.offset] : nil
        }
        
        mutating 
        func extend(with vertices:[Vertex], of culture:(id:Module.ID, index:Module.Index),
            _ register:(Symbol.ID, Symbol.Index) throws -> ()) rethrows -> Range<Int>
        {
            var inferred:Set<Symbol.ID> = [], 
                protocols:[Symbol.ID: (name:String, members:[Symbol.Index])] = [:]
            
            let start:Int = self.nodes.endIndex
            for vertex:Vertex in vertices 
            {
                // comb through generic constraints looking for references to 
                // underscored protocols and associatedtypes
                for constraint:Generic.Constraint<Symbol.ID> in 
                    [vertex.content.genericConstraints, vertex.content.extensionConstraints].joined()
                {
                    guard let id:Symbol.ID = constraint.link 
                    else 
                    {
                        continue 
                    }
                    if  case (culture.id, let mythical)? = id.interface, 
                        case "_"? = mythical.name.first
                    {
                        if case nil = inferred.update(with: id)
                        {
                            protocols[id, default: (mythical.name, [])].members.append(contentsOf: EmptyCollection.init())
                        }
                    }
                }
                
                // about half of the symbols in a typical symbol graph are non-canonical. 
                // (i.e., they are inherited by victims). in theory, these symbols can 
                // recieve documentation through article bindings, but it is very 
                // unlikely that the symbol graph vertices themselves contain 
                // useful information. 
                // 
                // that said, we cannot ignore non-canonical symbols altogether, because 
                // if their canonical base originates from an underscored protocol 
                // (or is implicitly private itself), then the non-canonical symbols 
                // are our only source of information about the canonical base. 
                // 
                // example: UnsafePointer.predecessor() actually originates from 
                // the witness `ss8_PointerPsE11predecessorxyF`, which is part of 
                // the underscored `_Pointer` protocol.
                let index:Symbol.Index = .init(culture.index, offset: self.nodes.endIndex)
                guard case .synthesized(namespace: let namespace) = vertex.kind
                else 
                {
                    try register(vertex.content.id, index)
                    self.nodes.append(.init(vertex))
                    continue 
                }
                guard namespace == culture.id 
                else 
                {
                    // only infer symbols if they are referenced from their home module
                    continue 
                }
                guard case nil = inferred.update(with: vertex.content.id)
                else 
                {
                    // already have a copy of this mythical declaration
                    continue 
                }
                
                if  case (culture.id, let mythical)? = vertex.content.id.interface, 
                    case "_"? = mythical.name.first
                {
                    // if the symbol is synthetic and belongs to an underscored 
                    // protocol, assume the generic base does not exist, and register 
                    // the synthesized copy instead.
                    try register(vertex.content.id, index)
                    self.nodes.append(.init(vertex))
                    
                    protocols[mythical.id, default: (mythical.name, [])].members.append(index)
                    
                    print("note: inferred mythical protocol member '\(vertex.content.id.string)' (\(vertex.content.id.description))")
                }
                else if case true? = vertex.content.availability.general?.unavailable
                {
                    // if the symbol is unconditionally unavailable, assume the generic 
                    // base does not exist (omitted by SymbolGraphGen), and register the 
                    // synthesized copy anyway.
                    try register(vertex.content.id, index)
                    self.nodes.append(.init(vertex))
                    print("note: naturalized blacklisted protocol member '\(vertex.content.id.string)' (\(vertex.content.id.description))")
                }
            }
            // register mythical protocols 
            for (id, mythical):(Symbol.ID, (name:String, members:[Symbol.Index])) in protocols 
            {
                let index:Symbol.Index = .init(culture.index, offset: self.nodes.endIndex)
                try register(id, index)
                self.nodes.append(.init(protocol: (mythical.name, id), members: mythical.members))
                // all of these symbol indices are local
                for member:Symbol.Index in mythical.members 
                {
                    self.nodes[member.offset].relationships.append(.is(.member(of: index)))
                }
                print("note: inferred mythical protocol '\(mythical.name)' (\(id))")
            }
            return start ..< self.nodes.endIndex
        }
        
        mutating 
        func link(_ subject:Symbol.Index, _ predicate:Symbol.Relationship, accordingTo perpetrator:Module.Index) 
            throws -> (subject:Symbol.Index, has:Symbol.Trait)?
        {
            switch predicate
            {
            case  .is(let role):
                guard perpetrator == subject.module
                else 
                {
                    throw Symbol.RelationshipError.unauthorized(perpetrator, says: subject, is: role)
                }
            case .has(let trait):
                guard self.package == subject.module.package
                else 
                {
                    return (subject, has: trait)
                }
            }
            
            self.nodes[subject.offset].relationships.append(predicate)
            return nil
        }
        
        mutating 
        func deduplicate(_ sponsored:Symbol.Index, against papers:String, from sponsor:Symbol.Index) 
            throws
        {
            switch self[sponsored]?.legality
            {
            case nil:
                // cannot sponsor symbols from another package (but symbols in 
                // another package can sponsor symbols in this package)
                throw Symbol.SponsorshipError.unauthorized(self.package, says: sponsored, isSponsoredBy: sponsor)
            
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
        }
    }
}

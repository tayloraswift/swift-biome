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
        func extend(with vertices:[Vertex], where predicate:(Int, Vertex) throws -> Bool) 
            rethrows -> Range<Int>
        {
            let start:Int = self.nodes.endIndex
            for vertex:Vertex in vertices where try predicate(self.nodes.endIndex, vertex)
            {
                self.nodes.append(.init(vertex))
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

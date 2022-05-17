extension Module 
{
    struct Node 
    {
        let local:Set<Index>, 
            upstream:Set<Index>
        
        init(local:Set<Index>, upstream:Set<Index>)
        {
            self.local = local 
            self.upstream = upstream
        }
        
        func upstream(given ecosystem:Ecosystem) -> Scope 
        {
            let packages:Set<Package.Index> = .init(self.upstream.map(\.package))
            return .init(filter: self.upstream, lenses: packages.map { ecosystem[$0].lens })
        }
        
        func namespaces(given ecosystem:Ecosystem, local:Package) -> [ID: Index] 
        {
            var namespaces:[ID: Index] 
                namespaces.reserveCapacity(self.local.count + self.upstream.count)
            for dependency:Index in self.upstream 
            {
                namespaces[   ecosystem[dependency].id] = dependency
            }
            for dependency:Index in self.local 
            {
                namespaces[local[local: dependency].id] = dependency
            }
            return namespaces
        }
    }
}

import SymbolGraphs

extension Symbol.Predicates:Sendable where Position:Sendable 
{
}
extension Symbol 
{
    @available(*, deprecated)
    typealias Statement = (subject:Index, predicate:Predicate)
    
    @available(*, deprecated, renamed: "Belief.Predicate")
    typealias Predicate = Belief.Predicate 
    
    struct Predicates<Position>:Equatable where Position:Hashable
    {
        let roles:Branch.SymbolRoles?
        var primary:Branch.SymbolTraits
        var accepted:[Module.Index: Branch.SymbolTraits]
        
        init(roles:Branch.SymbolRoles?, primary:Branch.SymbolTraits = .init())
        {
            self.roles = roles 
            self.primary = primary
            self.accepted = [:]
        }


        func map<T>(_ transform:(Position) throws -> T) rethrows -> Predicates<T> 
            where T:Hashable
        {
            fatalError("unimplemented")
        }
    }
}

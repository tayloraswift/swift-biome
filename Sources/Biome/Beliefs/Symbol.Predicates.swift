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
        let roles:Roles<Position>?
        var primary:Traits<Position>
        var accepted:[Module.Index: Traits<Position>]
        
        init(roles:Roles<Position>?, primary:Traits<Position> = .init())
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

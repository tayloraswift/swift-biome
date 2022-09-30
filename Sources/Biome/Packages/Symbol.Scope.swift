extension Symbol.Scope:Equatable where Position:Equatable {}
extension Symbol.Scope:Hashable where Position:Hashable {}
extension Symbol.Scope:Sendable where Position:Sendable {}
extension Symbol 
{
    // should have stride of 16 B, as well as `Scope?` and `Scope??`
    enum Scope<Position>
    {
        case member(of:Position)
        case requirement(of:Position)
        
        var role:Role<Position>
        {
            switch self 
            {
            case .member(of: let target):       return .member(of: target)
            case .requirement(of: let target):  return .requirement(of: target)
            }
        }
        var target:Position 
        {
            switch self 
            {
            case .member(let index), .requirement(let index): 
                return index
            }
        }
        
        func map<T>(_ transform:(Position) throws -> T) rethrows -> Scope<T>
        {
            switch self 
            {
            case .member(of: let target): 
                return .member(of: try transform(target))
            case .requirement(of: let target): 
                return .requirement(of: try transform(target))
            }
        }
    }
}

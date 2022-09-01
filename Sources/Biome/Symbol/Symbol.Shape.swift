extension Symbol.Shape:Equatable where Position:Equatable {}
extension Symbol.Shape:Hashable where Position:Hashable {}
extension Symbol.Shape:Sendable where Position:Sendable {}
extension Symbol 
{
    // should have stride of 16 B, as well as `Shape?` and `Shape??`
    enum Shape<Position>
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
        
        func map<T>(_ transform:(Position) throws -> T) rethrows -> Shape<T>
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

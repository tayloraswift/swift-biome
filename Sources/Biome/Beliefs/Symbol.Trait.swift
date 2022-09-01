import SymbolGraphs

extension Symbol.Trait:Equatable where Position:Equatable {}
extension Symbol.Trait:Sendable where Position:Sendable {}
extension Symbol 
{
    enum Trait<Position>
    {
        // members 
        case member(Position)
        case feature(Position)
        // implementations 
        case implementation(Position)
        // downstream
        case refinement(Position)
        case subclass(Position)
        case override(Position)
        // conformers
        case conformer(Generic.Conditional<Position>)
        // conformances
        case conformance(Generic.Conditional<Position>)
        
        var feature:Position? 
        {
            if case .feature(let feature) = self 
            {
                return feature
            }
            else 
            {
                return nil
            }
        }
        
        func map<T>(_ transform:(Position) throws -> T) rethrows -> Trait<T>
        {
            switch self 
            {
            case .member(let target): 
                return .member(try transform(target))
            case .feature(let target): 
                return .feature(try transform(target))
            case .implementation(let target): 
                return .implementation(try transform(target))
            case .refinement(let target): 
                return .refinement(try transform(target))
            case .subclass(let target): 
                return .subclass(try transform(target))
            case .override(let target): 
                return .override(try transform(target))
            case .conformer(let target): 
                return .conformer(try target.map(transform))
            case .conformance(let target): 
                return .conformance(try target.map(transform))
            }
        }
    }
}

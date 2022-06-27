extension Symbol 
{
    // should have stride of 8 B
    enum Kind:Sendable, Hashable 
    {
        case `associatedtype`
        case  concretetype(ConcreteType, path:Route.Stem)
        case  callable(Callable)
        case  global(Global)
        case `protocol`
        case `typealias`
        
        var path:Route.Stem?
        {
            if case .concretetype(_, path: let path) = self 
            {
                return path 
            }
            else 
            {
                return nil 
            }
        }
        var color:Color 
        {
            switch self 
            {
            case .associatedtype:                       return .associatedtype
            case .concretetype(let specifier, path: _): return .concretetype(specifier)
            case .callable(let specifier):              return .callable(specifier)
            case .global(let specifier):                return .global(specifier)
            case .protocol:                             return .protocol
            case .typealias:                            return .typealias
            }
        }
    }
}

import SymbolGraphs

extension Symbol 
{
    @available(*, deprecated, renamed: "Community")
    public 
    typealias Color = Community 

    // should have stride of 8 B
    enum Kind:Sendable, Hashable 
    {
        case `associatedtype`
        case  concretetype(Community.ConcreteType, path:Route.Stem)
        case  callable(Community.Callable)
        case  global(Community.Global)
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
        @available(*, deprecated, renamed: "community")
        var color:Color 
        {
            self.community
        }
        var community:Community 
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
extension Community 
{
    var orientation:Symbol.Link.Orientation 
    {
        switch self
        {
        case .concretetype(_), .associatedtype, .protocol, .typealias:
            return .straight
        case .callable(_), .global(_):
            return .gay
        }
    }
    
    var title:String 
    {
        switch self 
        {
        case .associatedtype:               return "Associated Type"
        case .protocol:                     return "Protocol"
        case .typealias:                    return "Typealias"
        case .concretetype(.enum):          return "Enumeration"
        case .concretetype(.struct):        return "Structure"
        case .concretetype(.class):         return "Class"
        case .concretetype(.actor):         return "Actor"
        case .callable(.case):              return "Enumeration Case"
        case .callable(.initializer):       return "Initializer"
        case .callable(.deinitializer):     return "Deinitializer"
        case .callable(.typeSubscript):     return "Type Subscript"
        case .callable(.instanceSubscript): return "Instance Subscript"
        case .callable(.typeProperty):      return "Type Property"
        case .callable(.instanceProperty):  return "Instance Property"
        case .callable(.typeMethod):        return "Type Method"
        case .callable(.instanceMethod):    return "Instance Method"
        case .callable(.typeOperator):      return "Type Operator"
        case .global(.operator):            return "Operator"
        case .global(.func):                return "Function"
        case .global(.var):                 return "Variable"
        }
    }
    
    var plural:String 
    {
        switch self 
        {
        case .associatedtype:               return "Associated Types"
        case .protocol:                     return "Protocols"
        case .typealias:                    return "Typealiases"
        case .concretetype(.enum):          return "Enumerations"
        case .concretetype(.struct):        return "Structures"
        case .concretetype(.class):         return "Classes"
        case .concretetype(.actor):         return "Actors"
        case .callable(.case):              return "Enumeration Cases"
        case .callable(.initializer):       return "Initializers"
        case .callable(.deinitializer):     return "Deinitializers"
        case .callable(.typeSubscript):     return "Type Subscripts"
        case .callable(.instanceSubscript): return "Instance Subscripts"
        case .callable(.typeProperty):      return "Type Properties"
        case .callable(.instanceProperty):  return "Instance Properties"
        case .callable(.typeMethod):        return "Type Methods"
        case .callable(.instanceMethod):    return "Instance Methods"
        case .callable(.typeOperator):      return "Type Operators"
        case .global(.operator):            return "Operators"
        case .global(.func):                return "Functions"
        case .global(.var):                 return "Variables"
        }
    }
}
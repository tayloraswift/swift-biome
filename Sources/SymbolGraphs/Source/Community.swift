@frozen public 
enum Community:Hashable, Comparable, Sendable
{
    @frozen public 
    enum ConcreteType:Sendable, Comparable, Hashable
    {
        case `enum`
        case `struct`
        case `class`
        case  actor
    }
    @frozen public 
    enum Callable:Sendable, Comparable, Hashable
    {
        case `case`
        case  initializer
        case  deinitializer
        case  typeSubscript
        case  instanceSubscript
        case  typeProperty
        case  instanceProperty
        case  typeMethod
        case  instanceMethod
        case  typeOperator
    }
    @frozen public 
    enum Global:Sendable, Comparable, Hashable 
    {
        case `operator`
        case `func`
        case `var`
    }

    case `protocol`
    case `associatedtype`
    case  concretetype(ConcreteType)
    case  callable(Callable)
    case  global(Global)
    case `typealias`
    
    public static 
    let `class`:Self = .concretetype(.class)
}
extension Community:RawRepresentable 
{
    @inlinable public 
    init?(rawValue:Int)
    {
        switch rawValue 
        {
        case  0: self = .protocol
        case  1: self = .associatedtype
        case  2: self = .concretetype(.enum)
        case  3: self = .concretetype(.struct)
        case  4: self = .concretetype(.class)
        case  5: self = .concretetype(.actor)
        case  6: self = .callable(.case)
        case  7: self = .callable(.initializer)
        case  8: self = .callable(.deinitializer)
        case  9: self = .callable(.typeSubscript)
        case 10: self = .callable(.instanceSubscript)
        case 11: self = .callable(.typeProperty)
        case 12: self = .callable(.instanceProperty)
        case 13: self = .callable(.typeMethod)
        case 14: self = .callable(.instanceMethod)
        case 15: self = .callable(.typeOperator)
        case 16: self = .global(.operator)
        case 17: self = .global(.func)
        case 18: self = .global(.var)
        case 19: self = .typealias
        default: return nil
        }
    }
    @inlinable public 
    var rawValue:Int 
    {
        switch self 
        {
        case .protocol:                     return  0
        case .associatedtype:               return  1
        case .concretetype(.enum):          return  2
        case .concretetype(.struct):        return  3
        case .concretetype(.class):         return  4
        case .concretetype(.actor):         return  5
        case .callable(.case):              return  6
        case .callable(.initializer):       return  7
        case .callable(.deinitializer):     return  8
        case .callable(.typeSubscript):     return  9
        case .callable(.instanceSubscript): return 10
        case .callable(.typeProperty):      return 11
        case .callable(.instanceProperty):  return 12
        case .callable(.typeMethod):        return 13
        case .callable(.instanceMethod):    return 14
        case .callable(.typeOperator):      return 15
        case .global(.operator):            return 16
        case .global(.func):                return 17
        case .global(.var):                 return 18
        case .typealias:                    return 19
        }
    }
} 
extension Community:CaseIterable 
{
    public static 
    let allCases:[Self] = 
    [
        .callable(.case),
        .associatedtype,
        .typealias,
        .callable(.initializer),
        .callable(.deinitializer),
        .callable(.typeSubscript),
        .callable(.instanceSubscript),
        .callable(.typeProperty),
        .callable(.instanceProperty),
        .callable(.typeMethod),
        .callable(.instanceMethod),
        .global(.var),
        .global(.func),
        .global(.operator),
        .callable(.typeOperator),
        .concretetype(.enum),
        .concretetype(.struct),
        .concretetype(.class),
        .concretetype(.actor),
        .protocol,
    ]
}
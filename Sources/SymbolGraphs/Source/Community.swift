@frozen public 
enum Community:Hashable, Sendable
{
    @frozen public 
    enum ConcreteType:Sendable, Hashable
    {
        case `enum`
        case `struct`
        case `class`
        case  actor
    }
    @frozen public 
    enum Callable:Sendable, Hashable
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
    enum Global:Sendable, Hashable 
    {
        case `var`
        case `func`
        case `operator`
    }

    case `associatedtype`
    case  concretetype(ConcreteType)
    case  callable(Callable)
    case  global(Global)
    case `protocol`
    case `typealias`
    
    public static 
    let `class`:Self = .concretetype(.class)
}
extension Community:RawRepresentable 
{
    @inlinable public 
    init?(rawValue:String)
    {
        switch rawValue 
        {
        case "swift.associatedtype":    self = .associatedtype
        case "swift.protocol":          self = .protocol
        case "swift.typealias":         self = .typealias
        case "swift.enum":              self = .concretetype(.enum)
        case "swift.struct":            self = .concretetype(.struct)
        case "swift.class":             self = .concretetype(.class)
        case "swift.actor":             self = .concretetype(.actor) // not an actual color string
        case "swift.enum.case":         self = .callable(.case)
        case "swift.init":              self = .callable(.initializer)
        case "swift.deinit":            self = .callable(.deinitializer)
        case "swift.type.subscript":    self = .callable(.typeSubscript)
        case "swift.subscript":         self = .callable(.instanceSubscript)
        case "swift.type.property":     self = .callable(.typeProperty)
        case "swift.property":          self = .callable(.instanceProperty)
        case "swift.type.method":       self = .callable(.typeMethod)
        case "swift.method":            self = .callable(.instanceMethod)
        case "swift.type.method.op":    self = .callable(.typeOperator) // not an actual color string
        case "swift.func.op":           self = .global(.operator)
        case "swift.func":              self = .global(.func)
        case "swift.var":               self = .global(.var)
        default: return nil
        }
    }
    @inlinable public 
    var rawValue:String 
    {
        switch self 
        {
        case .associatedtype:               return "swift.associatedtype"
        case .protocol:                     return "swift.protocol"
        case .typealias:                    return "swift.typealias"
        case .concretetype(.enum):          return "swift.enum"
        case .concretetype(.struct):        return "swift.struct"
        case .concretetype(.class):         return "swift.class"
        case .concretetype(.actor):         return "swift.actor" // not an actual color string
        case .callable(.case):              return "swift.enum.case"
        case .callable(.initializer):       return "swift.init"
        case .callable(.deinitializer):     return "swift.deinit"
        case .callable(.typeSubscript):     return "swift.type.subscript"
        case .callable(.instanceSubscript): return "swift.subscript"
        case .callable(.typeProperty):      return "swift.type.property"
        case .callable(.instanceProperty):  return "swift.property"
        case .callable(.typeMethod):        return "swift.type.method"
        case .callable(.instanceMethod):    return "swift.method"
        case .callable(.typeOperator):      return "swift.type.method.op" // not an actual color string
        case .global(.operator):            return "swift.func.op"
        case .global(.func):                return "swift.func"
        case .global(.var):                 return "swift.var"
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
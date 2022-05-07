extension Symbol 
{
    @available(*, deprecated, renamed: "Color")
    typealias Kind = Color 
    
    enum Orientation:Unicode.Scalar
    {
        case gay        = "."
        case straight   = "/"
    }
    enum Color:Sendable, Hashable, RawRepresentable
    {
        enum ConcreteType:Sendable, Hashable
        {
            case `enum`
            case `struct`
            case `class`
            case  actor
        }
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
            
            case `operator`
            
            case `var`
            case `func`
        }
        
        case `associatedtype`
        case `protocol`
        case `typealias`
        case  concretetype(ConcreteType)
        case  callable(Callable)
        
        static 
        let `class`:Self = .concretetype(.class)

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
            case "swift.actor":             self = .concretetype(.actor)
            case "swift.enum.case":         self = .callable(.case)
            case "swift.init":              self = .callable(.initializer)
            case "swift.deinit":            self = .callable(.deinitializer)
            case "swift.type.subscript":    self = .callable(.typeSubscript)
            case "swift.subscript":         self = .callable(.instanceSubscript)
            case "swift.type.property":     self = .callable(.typeProperty)
            case "swift.property":          self = .callable(.instanceProperty)
            case "swift.type.method":       self = .callable(.typeMethod)
            case "swift.method":            self = .callable(.instanceMethod)
            case "swift.func.op":           self = .callable(.operator)
            case "swift.func":              self = .callable(.func)
            case "swift.var":               self = .callable(.var)
            default: return nil
            }
        }
        
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
            case .concretetype(.actor):         return "swift.actor"
            case .callable(.case):              return "swift.enum.case"
            case .callable(.initializer):       return "swift.init"
            case .callable(.deinitializer):     return "swift.deinit"
            case .callable(.typeSubscript):     return "swift.type.subscript"
            case .callable(.instanceSubscript): return "swift.subscript"
            case .callable(.typeProperty):      return "swift.type.property"
            case .callable(.instanceProperty):  return "swift.property"
            case .callable(.typeMethod):        return "swift.type.method"
            case .callable(.instanceMethod):    return "swift.method"
            case .callable(.operator):          return "swift.func.op"
            case .callable(.func):              return "swift.func"
            case .callable(.var):               return "swift.var"
            }
        }
        
        @available(*, deprecated)
        var capitalized:Bool 
        {
            switch self
            {
            case .associatedtype, .concretetype, .typealias, .protocol:
                return true
            case .callable:
                return false
            }
        }
        var orientation:Orientation 
        {
            switch self
            {
            case .concretetype(_), .associatedtype, .protocol, .typealias:
                return .straight
            case .callable(_):
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
            case .callable(.operator):          return "Operator"
            case .callable(.func):              return "Function"
            case .callable(.var):               return "Global Variable"
            }
        }
    }
}

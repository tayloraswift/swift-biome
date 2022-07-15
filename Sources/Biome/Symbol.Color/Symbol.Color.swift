extension Symbol 
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
    @frozen public 
    enum Color:Hashable, CaseIterable, RawRepresentable, Sendable
    {
        case `associatedtype`
        case  concretetype(ConcreteType)
        case  callable(Callable)
        case  global(Global)
        case `protocol`
        case `typealias`
        
        static 
        let `class`:Self = .concretetype(.class)

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
        
        var orientation:Link.Orientation 
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
}

extension Symbol 
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
        case  typeOperator
    }
    enum Global:Sendable, Hashable 
    {
        case `var`
        case `func`
        case `operator`
    }
    enum Kind:Sendable 
    {
        case `associatedtype`
        case `enum`(Route.Stem)
        case `struct`(Route.Stem)
        case `class`(Route.Stem)
        case `actor`(Route.Stem)
        case `case`
        case  initializer
        case  deinitializer
        case  typeSubscript
        case  instanceSubscript
        case  typeProperty
        case  instanceProperty
        case  typeMethod
        case  instanceMethod
        case `typeOperator`
        case `var`
        case `func`
        case `operator`
        case `protocol`
        case `typealias`
        
        var path:Route.Stem?
        {
            switch self 
            {
            case    .enum(let path), 
                    .struct(let path), 
                    .class(let path), 
                    .actor(let path):
                return path 
            default: 
                return nil 
            }
        }
        
        static 
        func concretetype(_ subtype:ConcreteType, path:Route.Stem) -> Self 
        {
            switch subtype 
            {
            case .enum:                 return .enum(path)
            case .struct:               return .struct(path)
            case .class:                return .class(path)
            case .actor:                return .actor(path)
            }
        }
        static 
        func callable(_ subtype:Callable) -> Self 
        {
            switch subtype 
            {
            case .case:                 return .case
            case .initializer:          return .initializer
            case .deinitializer:        return .deinitializer
            case .typeSubscript:        return .typeSubscript
            case .instanceSubscript:    return .instanceSubscript
            case .typeProperty:         return .typeProperty
            case .instanceProperty:     return .instanceProperty
            case .typeMethod:           return .typeMethod
            case .instanceMethod:       return .instanceMethod
            case .typeOperator:         return .typeOperator
            }
        }
        static 
        func global(_ subtype:Global) -> Self 
        {
            switch subtype 
            {
            case .var:                  return .var
            case .func:                 return .func
            case .operator:             return .operator
            }
        }
        
        var color:Color 
        {
            switch self 
            {
            case .associatedtype:       return .associatedtype
            case .enum(_):              return .concretetype(.enum)
            case .struct(_):            return .concretetype(.struct)
            case .class(_):             return .concretetype(.class)
            case .actor(_):             return .concretetype(.actor)
            case .case:                 return .callable(.case)
            case .initializer:          return .callable(.initializer)
            case .deinitializer:        return .callable(.deinitializer)
            case .typeSubscript:        return .callable(.typeSubscript)
            case .instanceSubscript:    return .callable(.instanceSubscript)
            case .typeProperty:         return .callable(.typeProperty)
            case .instanceProperty:     return .callable(.instanceProperty)
            case .typeMethod:           return .callable(.typeMethod)
            case .instanceMethod:       return .callable(.instanceMethod)
            case .typeOperator:         return .callable(.typeOperator)
            case .var:                  return .global(.var)
            case .func:                 return .global(.func)
            case .operator:             return .global(.operator)
            case .protocol:             return .protocol
            case .typealias:            return .typealias
            }
        }
    }
    enum Color:Sendable, Hashable, RawRepresentable
    {
        case `associatedtype`
        case  concretetype(ConcreteType)
        case  callable(Callable)
        case  global(Global)
        case `protocol`
        case `typealias`
        
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
        
        var orientation:Route.Orientation 
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
            case .global(.operator):            return "Global Operator"
            case .global(.func):                return "Global Function"
            case .global(.var):                 return "Global Variable"
            }
        }
    }
}

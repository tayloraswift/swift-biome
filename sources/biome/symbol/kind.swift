extension Symbol 
{
    enum Kind:String, Sendable, Hashable
    {
        case `case`             = "swift.enum.case"
        case `associatedtype`   = "swift.associatedtype"
        case `typealias`        = "swift.typealias"
        
        case initializer        = "swift.init"
        case deinitializer      = "swift.deinit"
        case typeSubscript      = "swift.type.subscript"
        case instanceSubscript  = "swift.subscript"
        case typeProperty       = "swift.type.property"
        case instanceProperty   = "swift.property"
        case typeMethod         = "swift.type.method"
        case instanceMethod     = "swift.method"
        
        case `var`              = "swift.var"
        case `func`             = "swift.func"
        case `operator`         = "swift.func.op"
        case `enum`             = "swift.enum"
        case `struct`           = "swift.struct"
        case `class`            = "swift.class"
        case  actor             = "swift.actor"
        case `protocol`         = "swift.protocol"
        
        @available(*, deprecated)
        var capitalized:Bool 
        {
            switch self
            {
            case    .associatedtype, .typealias, .enum, .struct, .class, .actor, .protocol:
                return true
            case    .case, .initializer, .deinitializer, 
                    .typeSubscript, .instanceSubscript, 
                    .typeProperty, .instanceProperty, 
                    .typeMethod, .instanceMethod, 
                    .var, .func, .operator:
                return false
            }
        }
        
        public 
        var topic:Documentation.Topic.Automatic
        {
            switch self 
            {
            case .case:                 return .case
            case .associatedtype:       return .associatedtype
            case .typealias:            return .typealias
            case .initializer:          return .initializer
            case .deinitializer:        return .deinitializer
            case .typeSubscript:        return .typeSubscript
            case .instanceSubscript:    return .instanceSubscript
            case .typeProperty:         return .typeProperty
            case .instanceProperty:     return .instanceProperty
            case .typeMethod:           return .typeMethod
            case .instanceMethod:       return .instanceMethod
            case .var:                  return .global
            case .func:                 return .function
            case .operator:             return .operator
            case .enum:                 return .enum
            case .struct:               return .struct
            case .class:                return .class
            case .actor:                return .actor
            case .protocol:             return .protocol
            }
        }
        
        var title:String 
        {
            switch self 
            {
            case .case:                 return "Enumeration Case"
            case .associatedtype:       return "Associated Type"
            case .typealias:            return "Typealias"
            case .initializer:          return "Initializer"
            case .deinitializer:        return "Deinitializer"
            case .typeSubscript:        return "Type Subscript"
            case .instanceSubscript:    return "Instance Subscript"
            case .typeProperty:         return "Type Property"
            case .instanceProperty:     return "Instance Property"
            case .typeMethod:           return "Type Method"
            case .instanceMethod:       return "Instance Method"
            case .var:                  return "Global Variable"
            case .func:                 return "Function"
            case .operator:             return "Operator"
            case .enum:                 return "Enumeration"
            case .struct:               return "Structure"
            case .class:                return "Class"
            case .actor:                return "Actor"
            case .protocol:             return "Protocol"
            }
        }
    }
}

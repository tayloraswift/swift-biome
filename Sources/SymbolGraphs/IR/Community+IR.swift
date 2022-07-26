import JSON 

extension Community 
{
    var serialized:JSON 
    {
        switch self 
        {
        case .protocol:                     return "protocol"
        case .associatedtype:               return "associatedtype"
        case .concretetype(.enum):          return "enum"
        case .concretetype(.struct):        return "struct"
        case .concretetype(.class):         return "class"
        case .concretetype(.actor):         return "actor"
        case .callable(.case):              return "case"
        case .callable(.initializer):       return "initializer"
        case .callable(.deinitializer):     return "deinitializer"
        case .callable(.typeSubscript):     return "typeSubscript"
        case .callable(.instanceSubscript): return "instanceSubscript"
        case .callable(.typeProperty):      return "typeProperty"
        case .callable(.instanceProperty):  return "instanceProperty"
        case .callable(.typeMethod):        return "typeMethod"
        case .callable(.instanceMethod):    return "instanceMethod"
        case .callable(.typeOperator):      return "typeOperator"
        case .global(.operator):            return "operator"
        case .global(.func):                return "func"
        case .global(.var):                 return "var"
        case .typealias:                    return "typealias"
        }
    }
}
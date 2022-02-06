import JSON 

enum SwiftLanguage 
{
    struct Lexeme 
    {
        enum Kind:String 
        {
            // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/DeclarationFragmentPrinter.cpp
            case keyword    = "keyword"
            case attribute  = "attribute"
            case number     = "number"
            case string     = "string"
            case identifier = "identifier"
            case type       = "typeIdentifier"
            case generic    = "genericParameter"
            case parameter  = "internalParam"
            case label      = "externalParam"
            case text       = "text"
        }
        
        let text:String 
        let kind:Kind
        let reference:String?
    }
}
extension SwiftLanguage.Lexeme:Codable 
{
    enum CodingKeys:String, CodingKey 
    {
        case text       = "spelling"
        case kind       = "kind"
        case reference  = "preciseIdentifier"
    }
}
extension SwiftLanguage.Lexeme.Kind:Codable 
{
}

public 
enum Entrapta 
{
    public static 
    func documentation(symbolgraph utf8:[UInt8]) throws -> Documentation
    {
        let json:JSON   = try Grammar.parse(utf8, as: JSON.Rule<Array<UInt8>.Index>.Root.self)
        let graph:Graph = try .init(from: json)
        let documentation:Documentation = .init(graph: graph)
        
        return documentation
    }
    
    public final
    class Symbol 
    {
        public 
        let path:[String] 
        
        let title:String 
        let kind:Kind
        let declaration:[SwiftLanguage.Lexeme]
        
        let discussion:String
        
        var shortcut:String 
        {
            self.path.map { "/\($0)" }.joined()
        }
        
        init(_ descriptor:Graph.Symbol) 
        {
            self.path           = descriptor.path 
            self.title          = descriptor.display.title 
            self.kind           = descriptor.kind 
            self.declaration    = descriptor.declaration
            
            self.discussion     = descriptor.comment.joined(separator: "\n")
        }
    }
}
extension Entrapta.Symbol 
{
    enum Kind:String, Codable, CustomStringConvertible 
    {
        case enumeration        = "swift.enum"
        case enumerationCase    = "swift.enum.case"
        case structure          = "swift.struct"
        case `class`            = "swift.class"
        case `protocol`         = "swift.protocol"
        case initializer        = "swift.init"
        case deinitializer      = "swift.deinit"
        case `operator`         = "swift.func.op"
        case function           = "swift.func"
        case global             = "swift.var"
        case typeMethod         = "swift.type.method"
        case typeProperty       = "swift.type.property"
        case typeSubscript      = "swift.type.subscript"
        case instanceMethod     = "swift.method"
        case instanceProperty   = "swift.property"
        case instanceSubscript  = "swift.subscript"
        case `typealias`        = "swift.typealias"
        case `associatedtype`   = "swift.associatedtype"
        
        var description:String 
        {
            switch self 
            {
            case .enumeration:          return "Enumeration"
            case .enumerationCase:      return "Enumeration Case"
            case .structure:            return "Structure"
            case .`class`:              return "Class"
            case .`protocol`:           return "Protocol"
            case .initializer:          return "Initializer"
            case .deinitializer:        return "Deinitializer"
            case .`operator`:           return "Operator"
            case .function:             return "Function"
            case .global:               return "Global Variable"
            case .typeMethod:           return "Type Method"
            case .typeProperty:         return "Type Property"
            case .typeSubscript:        return "Type Subscript"
            case .instanceMethod:       return "Instance Method"
            case .instanceProperty:     return "Instance Property"
            case .instanceSubscript:    return "Instance Subscript"
            case .`typealias`:          return "Typealias"
            case .`associatedtype`:     return "Associated Type"
            }
        }
    }
}

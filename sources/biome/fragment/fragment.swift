import JSON 
import Notebook

struct Fragment:NotebookFragment 
{
    var text:String
    var link:Symbol.ID?
    var color:Color
    
    init(_ text:String, color:Color, link:Symbol.ID? = nil)
    {
        self.text = text 
        self.color = color 
        self.link = link
    }
    
}
extension Fragment 
{
    init(from json:JSON) throws 
    {
        (self.text, self.link, self.color) = try json.lint 
        {
            let link:Symbol.ID? = try $0.pop("preciseIdentifier", Symbol.ID.init(from:))
            let text:String = try $0.remove("spelling", as: String.self)
            let color:Color = try $0.remove("kind")
            {
                // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/DeclarationFragmentPrinter.cpp
                switch try $0.as(String.self) as String
                {
                case "keyword":
                    switch text 
                    {
                    case "init", "deinit", "subscript":
                                            return .keywordIdentifier
                    default:                return .keywordText
                    }
                case "attribute":           return .attribute
                case "number":              return .number
                case "string":              return .string
                case "identifier":          return .identifier
                case "typeIdentifier":      return .type
                case "genericParameter":    return .generic
                case "internalParam":       return .parameter
                case "externalParam":       return .argument
                case "text":                return .text
                case let color:
                    throw ColorError.undefined(color: color)
                }
            }
            return (text, link, color)
        }
    }
}

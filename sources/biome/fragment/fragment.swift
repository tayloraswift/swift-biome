import JSON 
import Notebook

extension Notebook<Highlight, Symbol.ID>.Fragment
{
    init(from json:JSON) throws 
    {
        self = try json.lint 
        {
            let text:String = try $0.remove("spelling", as: String.self)
            let link:Symbol.ID? = try $0.pop("preciseIdentifier", Symbol.ID.init(from:))
            let color:Highlight = try $0.remove("kind")
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
                    throw HighlightError.undefined(color: color)
                }
            }
            return .init(text, color: color, link: link)
        }
    }
}

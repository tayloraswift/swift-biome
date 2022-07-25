import JSON 
import Notebook

@frozen public
enum Highlight:UInt8, Sendable
{
    //  special semantic identifiers. only generated by the symbolgraph extractor
    case generic = 0
    case argument
    case parameter
    
    /// an attribute like '@frozen'
    case attribute
    case comment
    /// '#warning', etc.
    case directive
    case documentationComment
    case identifier
    case interpolation
    case invalid
    /// 'init', 'deinit', 'subscript'
    case keywordIdentifier
    /// '#if', '#else', etc.
    case keywordDirective
    /// 'for', 'let', 'func', etc.
    case keywordText 
    case newlines
    case number
    // '$0'
    case pseudo
    case string 
    case text
    /// A type annotation, which appears after a colon. Not all references to a 
    /// type have this classification; some references are considered identifiers.
    case type
}

extension Notebook<Highlight, SymbolIdentifier>.Fragment
{
    init(from json:JSON) throws 
    {
        self = try json.lint 
        {
            let text:String = try $0.remove("spelling", as: String.self)
            let link:SymbolIdentifier? = 
                try $0.pop("preciseIdentifier", SymbolIdentifier.init(from:))
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
                    throw SymbolGraphDecodingError.invalidFragmentColor(color)
                }
            }
            return .init(text, color: color, link: link)
        }
    }
}

import SwiftSyntax
import SwiftSyntaxParser
import JSON 

public 
enum Language 
{
    public 
    struct Constraint
    {
        typealias DecodingError = Entrapta.DecodingError<JSON, Self>
        
        enum Verb
        {
            case inherits(from:Entrapta.Graph.Symbol.ID?)
            case conforms(to:Entrapta.Graph.Symbol.ID?)
            case `is`(Entrapta.Graph.Symbol.ID?)
        }
        
        var subject:String
        var verb:Verb 
        var object:String
        
        init(from json:JSON) throws 
        {
            guard case .object(var items) = json 
            else 
            {
                throw DecodingError.init(expected: [String: JSON].self, encountered: json)
            }
            defer 
            {
                if !items.isEmpty 
                {
                    print("warning: unused json keys \(items)")
                }
            }
            switch items.removeValue(forKey: "lhs")
            {
            case .string(let text)?:
                self.subject = text 
            case let value:
                throw DecodingError.init(expected: String.self, in: "lhs", encountered: value)
            }
            switch items.removeValue(forKey: "rhs")
            {
            case .string(let text)?:
                self.object = text 
            case let value:
                throw DecodingError.init(expected: String.self, in: "rhs", encountered: value)
            }
            let id:Entrapta.Graph.Symbol.ID?
            switch items.removeValue(forKey: "rhsPrecise")
            {
            case .null?, nil:
                id = nil 
            case .string(let text)?:
                id = .declaration(precise: text) 
            case let value?:
                throw DecodingError.init(expected: String?.self, in: "rhsPrecise", encountered: value)
            }
            // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/JSON.cpp
            switch items.removeValue(forKey: "kind")
            {
            case .string("superclass")?:
                self.verb = .inherits(from: id)
            case .string("conformance")?:
                self.verb = .conforms(to: id)
            case .string("sameType")?:
                self.verb = .is(id)
            case let value:
                throw DecodingError.init(expected: Verb.self, in: "kind", encountered: value)
            }
        }
    }
    public 
    enum Keyword 
    {
        case `init` 
        case `deinit` 
        case `subscript`
        case other 
    }
    public 
    enum Lexeme 
    {
        public 
        enum Class 
        {
            case punctuation 
            case type(Entrapta.Graph.Symbol.ID?)
            case identifier
            //  special semantic identifiers. only generated by the symbolgraph extractor
            case generic
            case argument
            case parameter
            //  example: `#warning`. should be colored like a keyword
            case directive 
            case keyword(Keyword) 
            case pseudo
            case number
            case string 
            case interpolation
            //  example: `#if`. should be colored like magic
            case macro 
            case attribute
        }
        
        case code(String, class:Class) 
        case comment(String, documentation:Bool = false)
        case invalid(String)
        case newlines(Int)
        case spaces(Int)
        
        typealias DecodingError = Entrapta.DecodingError<JSON, Self>
        
        init(from json:JSON) throws 
        {
            guard case .object(var items) = json 
            else 
            {
                throw DecodingError.init(expected: [String: JSON].self, encountered: json)
            }
            defer 
            {
                if !items.isEmpty 
                {
                    print("warning: unused json keys \(items)")
                }
            }
            let string:String 
            switch items.removeValue(forKey: "spelling")
            {
            case .string(let text)?:
                string = text 
            case let value:
                throw DecodingError.init(expected: String.self, in: "spelling", encountered: value)
            }
            let id:Entrapta.Graph.Symbol.ID?
            switch items.removeValue(forKey: "preciseIdentifier")
            {
            case .null?, nil:
                id = nil 
            case .string(let text)?:
                id = .declaration(precise: text) 
            case let value?:
                throw DecodingError.init(expected: String?.self, in: "preciseIdentifier", encountered: value)
            }
            // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/DeclarationFragmentPrinter.cpp
            switch items.removeValue(forKey: "kind")
            {
            case .string("keyword")?:
                let keyword:Keyword 
                switch string 
                {
                case "init":        keyword = .`init`
                case "deinit":      keyword = .deinit
                case "subscript":   keyword = .subscript
                default:            keyword = .other 
                }
                self = .code(string, class: .keyword(keyword))
            case .string("attribute")?:
                self = .code(string, class: .attribute)
            case .string("number")?:
                self = .code(string, class: .number) 
            case .string("string")?:
                self = .code(string, class: .string) 
            case .string("identifier")?:
                self = .code(string, class: .identifier) 
            case .string("typeIdentifier")?:
                self = .code(string, class: .type(id)) 
            case .string("genericParameter")?:
                self = .code(string, class: .generic) 
            case .string("internalParam")?:
                self = .code(string, class: .parameter) 
            case .string("externalParam")?:
                self = .code(string, class: .argument) 
            case .string("text")?:
                if string.allSatisfy(\.isWhitespace)
                {
                    self = .spaces(1)
                }
                else 
                {
                    self = .code(string, class: .punctuation) 
                }
            case let value:
                throw DecodingError.init(expected: Class.self, in: "kind", encountered: value)
            }
        }
    }
    static 
    func highlight(code:String) -> [Lexeme]
    {
        do 
        {
            return Self.highlight(tree: .init(try SyntaxParser.parse(source: code)))
        }
        catch let error 
        {
            return 
                [
                    .comment("//  highlighting error:"), .newlines(1),
                    .comment("//  \(error)"),
                ]
                + 
                code.split(separator: "\n", omittingEmptySubsequences: false).map 
                {
                    [
                        .newlines(1),
                        .comment(String.init($0)),
                    ]
                }.joined()
        }
    }
    static 
    func highlight(tree:Syntax) -> [Lexeme]
    {
        var lexemes:[Lexeme] = tree.tokens.flatMap 
        {
            (token:TokenSyntax) -> [Lexeme] in 
            if let lexeme:Lexeme = .init(token)
            {
                return 
                    token.leadingTrivia.map(Lexeme.init(_:))
                    +
                    CollectionOfOne<Lexeme>.init(lexeme)
                    +
                    token.trailingTrivia.map(Lexeme.init(_:))
            }
            else 
            {
                return 
                    token.leadingTrivia.map(Lexeme.init(_:))
                    +
                    token.trailingTrivia.map(Lexeme.init(_:))
            }
        }
        // strip trailing newlines 
        while case .newlines(_)? = lexemes.last 
        {
            lexemes.removeLast()
        }
        return lexemes
    }
}
extension Language.Lexeme 
{
    init(_ trivia:TriviaPiece)
    {
        switch trivia 
        {
        case .garbageText(let text): 
            self = .invalid(text)
        case .spaces(let count):
            self = .spaces(count)
        case .tabs(let count): 
            self = .spaces(count * 4)
        case .verticalTabs(let count), .formfeeds(let count):
            self = .spaces(count)
        case .newlines(let count), .carriageReturns(let count), .carriageReturnLineFeeds(let count):
            self = .newlines(count)
        case .lineComment(let string), .blockComment(let string):
            self = .comment(string, documentation: false)
        case .docLineComment(let string), .docBlockComment(let string):
            self = .comment(string, documentation: true)
        }
    }
    init?(_ token:TokenSyntax)
    {
        guard !token.text.isEmpty
        else 
        {
            return nil
        }
        let classification:Class 
        switch token.tokenClassification.kind 
        {
        case .none:                         classification = .punctuation 
        case .keyword:
            switch token.tokenKind 
            {
            case .initKeyword:              classification = .keyword(.`init`)
            case .deinitKeyword:            classification = .keyword(.deinit)
            case .subscriptKeyword:         classification = .keyword(.subscript)
            default:                        classification = .keyword(.other)
            }
            
        case .identifier:                   classification = .identifier
        case .typeIdentifier:               classification = .type(nil)
        case .dollarIdentifier:             classification = .pseudo
        case .integerLiteral:               classification = .number 
        case .floatingLiteral:              classification = .number
        case .stringLiteral:                classification = .string 
        case .stringInterpolationAnchor:    classification = .interpolation
        case .poundDirectiveKeyword:        classification = .directive 
        case .buildConfigId:                classification = .macro 
        case .attribute:                    classification = .attribute
        // only used by xcode 
        case .objectLiteral:                classification = .punctuation
        case .editorPlaceholder:            classification = .punctuation
        case .lineComment, .blockComment:   
            self = .comment(token.text, documentation: false)
            return 
        case .docLineComment, .docBlockComment:
            self = .comment(token.text, documentation: true)
            return 
        }
        self = .code(token.text, class: classification)
    }
}

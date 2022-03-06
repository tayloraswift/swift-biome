import SwiftSyntax
import SwiftSyntaxParser

@available(*, deprecated)
public 
typealias Language = SwiftLanguage

public 
enum SwiftLanguage 
{
    public 
    struct Constraint<Link>
    {
        enum Verb
        {
            case inherits(from:Link?)
            case conforms(to:Link?)
            case `is`(Link?)
        }
        
        var subject:String
        var verb:Verb 
        var object:String
    }
    public 
    enum Keyword:Sendable 
    {
        case `init` 
        case `deinit` 
        case `subscript`
        case other 
    }
    public 
    enum Lexeme<Link>
    {
        public 
        enum Class
        {
            case punctuation 
            case type(Link?)
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
    }
    static 
    func highlight<Link>(code:String, links _:Link.Type) -> [Lexeme<Link>]
    {
        do 
        {
            return Self.highlight(tree: .init(try SyntaxParser.parse(source: code)), links: Link.self)
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
    func highlight<Link>(tree:Syntax, links _:Link.Type) -> [Lexeme<Link>]
    {
        var lexemes:[Lexeme<Link>] = tree.tokens.flatMap 
        {
            (token:TokenSyntax) -> [Lexeme<Link>] in 
            if let lexeme:Lexeme<Link> = .init(token)
            {
                return 
                    token.leadingTrivia.map(Lexeme<Link>.init(_:))
                    +
                    CollectionOfOne<Lexeme<Link>>.init(lexeme)
                    +
                    token.trailingTrivia.map(Lexeme<Link>.init(_:))
            }
            else 
            {
                return 
                    token.leadingTrivia.map(Lexeme<Link>.init(_:))
                    +
                    token.trailingTrivia.map(Lexeme<Link>.init(_:))
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
extension SwiftLanguage.Constraint:Sendable where Link:Sendable {}
extension SwiftLanguage.Lexeme.Class:Sendable where Link:Sendable {}
extension SwiftLanguage.Lexeme:Sendable where Link:Sendable {}
extension SwiftLanguage.Lexeme 
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

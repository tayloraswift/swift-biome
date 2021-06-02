import SwiftSyntax

struct SwiftCode 
{
    struct Token 
    {
        enum Kind:Hashable 
        {
            case attribute
            case literal 
            case interpolation
            case punctuation
            case `operator`
            case keyword
            case pseudo
            case variable
            // prevent this from getting shadowed by anything
            case any 
            case type(qualified:[String])
            case comment
            case doccommentLine
            case doccommentBlock
            case whitespace(newlines:Int?)
        }
        
        let text:String 
        let kind:Kind 
        let location:SourceLocation
    }
}
extension SwiftCode.Token
{
    init?(_ token:TokenSyntax, location:SourceLocation)
    {
        self.location   = location 
        self.text       = token.text
        switch token.tokenKind 
        {
        case    .integerLiteral, 
                .floatingLiteral:
            self.kind = .literal
        case    .spacedBinaryOperator,
                .unspacedBinaryOperator,
                .postfixOperator,
                .prefixOperator, 
            // we can’t distinguish type puncutation, even with .tokenClassification, 
            // so we have to mark them as operators
                .equal,
                .exclamationMark, 
                .infixQuestionMark,
                .postfixQuestionMark,
                .leftSquareBracket, 
                .rightSquareBracket:
            self.kind = .operator
        case    .stringLiteral,
                .stringSegment, 
                .stringQuote, .singleQuote, .multilineStringQuote:
            self.kind = .literal
        case    .stringInterpolationAnchor:
            self.kind = .interpolation
        case    .rawStringDelimiter:
            self.kind = .literal
        case    .atSign:
            self.kind = .attribute
        case    .selfKeyword, 
                .superKeyword:
            self.kind = .pseudo
        case    .anyKeyword:
            self.kind = .any
        case    .breakKeyword,
                .caseKeyword,
                .continueKeyword,
                .defaultKeyword,
                .doKeyword,
                .elseKeyword,
                .fallthroughKeyword,
                .ifKeyword,
                .inKeyword,
                .forKeyword,
                .returnKeyword,
                .yield,
                .switchKeyword,
                .whereKeyword,
                .whileKeyword,
                .tryKeyword,
                .catchKeyword,
                .throwKeyword,
                .guardKeyword,
                .deferKeyword,
                .repeatKeyword,
                .asKeyword,
                .isKeyword,
                .capitalSelfKeyword,
                .__dso_handle__Keyword,
                .__column__Keyword,
                .__file__Keyword,
                .__function__Keyword,
                .__line__Keyword,
                .inoutKeyword,
                .operatorKeyword,
                .throwsKeyword,
                .rethrowsKeyword,
                .precedencegroupKeyword:
            self.kind = .keyword
        case    .classKeyword,
                .deinitKeyword,
                .enumKeyword,
                .extensionKeyword,
                .funcKeyword,
                .importKeyword,
                .initKeyword,
                .internalKeyword,
                .letKeyword,
                .privateKeyword,
                .protocolKeyword,
                .publicKeyword,
                .staticKeyword,
                .structKeyword,
                .subscriptKeyword,
                .typealiasKeyword,
                .varKeyword,
                .associatedtypeKeyword,
                .fileprivateKeyword:
            self.kind = .keyword
        case    .trueKeyword, .falseKeyword, .nilKeyword:
            self.kind = .literal
        case    .poundEndifKeyword,
                .poundElseKeyword,
                .poundElseifKeyword,
                .poundIfKeyword,
                .poundSourceLocationKeyword,
                .poundFileKeyword,
                .poundFileIDKeyword,
                .poundLineKeyword,
                .poundColumnKeyword,
                .poundDsohandleKeyword,
                .poundFunctionKeyword,
                .poundSelectorKeyword,
                .poundKeyPathKeyword,
                .poundColorLiteralKeyword,
                .poundFileLiteralKeyword,
                .poundImageLiteralKeyword,
                .poundFilePathKeyword,
                .poundAssertKeyword,
                .poundWarningKeyword,
                .poundErrorKeyword,
                .poundAvailableKeyword:
            self.kind = .keyword
        case    .contextualKeyword:
            self.kind = .pseudo
        case    .arrow, .comma, .period, .colon, .semicolon, .ellipsis,
                .backslash,
                .pound,
                .wildcardKeyword,
                .prefixAmpersand,
                .prefixPeriod,
                .backtick,
                .leftAngle, .rightAngle,
                .leftBrace, .rightBrace,
                .leftParen, .rightParen:
            self.kind = .punctuation
        case    .identifier("override"):
            self.kind = .keyword
        case    .identifier:
            switch token.tokenClassification.kind 
            {
            case .typeIdentifier:
                // get the fully qualified name 
                var components:[String]     = [token.text]
                var previous:TokenSyntax?   = token.previousToken 
                scan:
                while   let current:TokenSyntax = previous, 
                        case .period            = current.tokenKind
                {
                    previous = current.previousToken
                    // skip generic parameters 
                    var depth:Int = 0 
                    while let current:TokenSyntax = previous 
                    {
                        previous = current.previousToken 
                        if      case .rightAngle = current.tokenKind  
                        {
                            depth   += 1 
                            continue 
                        }
                        else if depth == 0 
                        {
                            guard   case .identifier        = current.tokenKind, 
                                    case .typeIdentifier    = current.tokenClassification.kind 
                            else 
                            {
                                break scan 
                            }
                            components.append(current.text)
                            continue scan 
                        }
                        else if case .leftAngle = current.tokenKind 
                        {
                            depth   -= 1
                            continue 
                        }
                    }
                    
                    break scan 
                }
                components.reverse()
                self.kind = .type(qualified: components)
            default:
                self.kind = .variable
            }
        case .dollarIdentifier:
            self.kind = .pseudo
        case .unknown:
            self.kind = .variable
        case .eof:
            return nil
        }
    }
    init(_ trivia:TriviaPiece, location:SourceLocation)
    {
        self.location = location 
        switch trivia 
        {
        case    .spaces,
                .tabs,
                .verticalTabs,
                .formfeeds,
                .garbageText:
            self.kind = .whitespace(newlines: nil)
        case    .newlines(let count),
                .carriageReturns(let count),
                .carriageReturnLineFeeds(let count):
            self.kind = .whitespace(newlines: count)
        case    .lineComment,
                .blockComment:
            self.kind = .comment
        case    .docLineComment:
            self.kind = .doccommentLine
        case    .docBlockComment:
            self.kind = .doccommentBlock
        }
        var string:String = ""
        print(trivia, terminator: "", to: &string)
        self.text = string
    }
}
extension SwiftCode 
{
    private final 
    class Visitor:SyntaxAnyVisitor 
    {
        private 
        let converter:SourceLocationConverter
        var tokens:[Token] 
        
        init(code:String, file:String = "<anonymous>")
        {
            self.converter  = .init(file: file, source: code)
            self.tokens     = []
        }
        
        override 
        func visitAny(_ node:Syntax) -> SyntaxVisitorContinueKind 
        {
            self.tokens.append(contentsOf: node.tokens.flatMap
            {
                (token:TokenSyntax) -> [Token] in 
                let position:AbsolutePosition = token.position 
                let location:SourceLocation   = .init(offset: position.utf8Offset, converter: self.converter)
                return token.leadingTrivia.map
                { 
                    Token.init($0, location: location) 
                }
                +
                (Token.init(token, location: location).map{ [$0] } ?? []) 
                +
                token.trailingTrivia.map
                {
                    Token.init($0, location: location) 
                }
            })
            return .visitChildren
        }
    }
    
    static 
    func tokenize(code:String) throws -> [Token]
    {
        let tree:SourceFileSyntax       = try SyntaxParser.parse(source: code)
        let visitor:Visitor             = .init(code: code)
        let _:SyntaxVisitorContinueKind = visitor.visit(tree)
        return visitor.tokens
    }
    static 
    func highlight(code:String) -> [(text:String, info:Paragraph.CodeBlock.TokenInfo)] 
    {
        guard let tokens:[Token] = try? Self.tokenize(code: code)
        else 
        {
            print("warning: could not highlight swift code snippet:")
            print("'''")
            print(code)
            print("'''")
            
            return [(code, .whitespace)]
        }
        return tokens.map 
        {
            let info:Paragraph.CodeBlock.TokenInfo
            switch $0.kind 
            {
            case    .attribute:         info = .attribute
            case    .literal:           info = .literal
            case    .interpolation:     info = .interpolation
            case    .punctuation:       info = .punctuation
            case    .operator:          info = .operator
            case    .keyword:           info = .keyword
            case    .pseudo:            info = .pseudo
            case    .variable:          info = .variable
            case    .any:
                info = .symbol(.init(builtin: ["Any"]))
            case    .type(qualified: let path):   
                info = .symbol(.unresolved(path: path))
            case    .comment, 
                    .doccommentLine, 
                    .doccommentBlock:          
                info = .comment
            case    .whitespace:
                info = .whitespace
            }
            return ($0.text, info)
        }
    }
}

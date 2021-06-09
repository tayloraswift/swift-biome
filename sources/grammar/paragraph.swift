enum Paragraph //:Grammar.Parsable
{
    struct Asterisk:Grammar.Parsable.Terminal
    {
        static 
        let token:String = "*"
    } 
    struct Tilde:Grammar.Parsable.Terminal
    {
        static 
        let token:String = "~"
    } 
    struct Ditto:Grammar.Parsable.Terminal
    {
        static 
        let token:String = "^"
    } 
    struct Newline:Grammar.Parsable.Terminal
    {
        static 
        let token:String = "\\n"
    } 
    //  ParagraphGrammar.Token  ::= <ParagraphLink> 
    //                            | <ParagraphSymbolLink>
    //                            | <ParagraphSubscript>
    //                            | <ParagraphSuperscript>
    //                            | '***'
    //                            | '**'
    //                            | '*'
    //                            | <ParagraphCodeBlock>
    //                            | .
    //  ParagraphSubscript      ::= '~' [^~] * '~'
    //  ParagraphSuperscript    ::= '^' [^\^] * '^'
    //  ParagraphInlineType     ::= '[[`' <Type> '`]]'
    //  ParagraphSymbolLink     ::= '[' <SymbolPath> <SymbolPath> * ( <Identifier> '`' ) * ']'
    //  SymbolPath              ::= '`' ( '(' <Identifiers> ').' ) ? <SymbolTail> 
    //                              ( <Whitespace> ? '#' <Whitespace> ? 
    //                                  '(' <Whitespace> ? <TopicKey> <Whitespace> ? ')' ) ?
    //                              '`'
    //  SymbolTail              ::= <FunctionIdentifiers> ? '(' <SymbolLabel> * ')' 
    //                            | <Identifiers>         ? '[' <SymbolLabel> * ']'
    //                            | <Identifiers>
    //  SymbolLabel             ::= <Identifier> '...' ? ':'
    //  ParagraphLink           ::= '[' [^\]] * '](' [^\)] ')'
    struct NotClosingBracket:Grammar.Parsable.CharacterClass
    {
        let character:Character 
        init?(_ character:Character) 
        {
            guard !character.isNewline && character != "]"
            else 
            {
                return nil 
            }
            self.character = character
        }
    } 
    struct NotClosingParenthesis:Grammar.Parsable.CharacterClass
    {
        let character:Character 
        init?(_ character:Character) 
        {
            guard !character.isNewline && character != ")"
            else 
            {
                return nil 
            }
            self.character = character
        }
    } 
    struct NotClosingTilde:Grammar.Parsable.CharacterClass
    {
        let character:Character 
        init?(_ character:Character) 
        {
            guard !character.isNewline && character != "~"
            else 
            {
                return nil 
            }
            self.character = character
        }
    } 
    struct NotClosingDitto:Grammar.Parsable.CharacterClass
    {
        let character:Character 
        init?(_ character:Character) 
        {
            guard !character.isNewline && character != "^"
            else 
            {
                return nil 
            }
            self.character = character
        }
    } 
    
    enum Element:Grammar.Parsable
    {
        enum Text:Grammar.Parsable
        {
            case star3
            case star2 
            case star1 
            case backtick(count:Int)
            case wildcard(Character)
            case newline 
            
            init(parsing input:inout Grammar.Input) throws 
            {
                let start:String.Index = input.index
                if      let _:List<Asterisk, List<Asterisk, Asterisk>> = 
                    .init(parsing: &input) 
                {
                    self = .star3
                }
                else if let _:List<Asterisk, Asterisk> = 
                    .init(parsing: &input) 
                {
                    self = .star2
                }
                else if let _:Asterisk = 
                    .init(parsing: &input) 
                {
                    self = .star1
                }
                else if let _:Newline = 
                    .init(parsing: &input) 
                {
                    self = .newline
                }
                else if let backticks:List<Grammar.Token.Backtick, [Grammar.Token.Backtick]> = 
                    .init(parsing: &input) 
                {
                    self = .backtick(count: 1 + backticks.body.count)
                }
                // escape sequences 
                else if let _:List<Grammar.Token.Backslash, Asterisk> = 
                    .init(parsing: &input) 
                {
                    self = .wildcard("*")
                }
                else if let _:List<Grammar.Token.Backslash, Grammar.Token.Backtick> = 
                    .init(parsing: &input) 
                {
                    self = .wildcard("`")
                }
                else if let _:List<Grammar.Token.Backslash, Grammar.Token.Backslash> = 
                    .init(parsing: &input) 
                {
                    self = .wildcard("\\")
                }
                else if let _:List<Grammar.Token.Backslash, Grammar.Token.Space> = 
                    .init(parsing: &input) 
                {
                    self = .wildcard("\u{A0}")
                }
                else if let character:Character = input.next()
                {
                    self = .wildcard(character)
                }
                else 
                {
                    throw input.expected(Self.self, from: start)
                }
            }
        }
        
        struct Link:Grammar.Parsable
        {
            let text:[Text], 
                url:String, 
                classes:[String]
            
            init(text:[Text], url:String, classes:[String] = []) 
            {
                self.text       = text 
                self.url        = url 
                self.classes    = classes 
            }
                
            init(parsing input:inout Grammar.Input) throws 
            {
                let _:Grammar.Token.Bracket.Left            = try .init(parsing: &input),
                    text:[NotClosingBracket]        =     .init(parsing: &input),
                    _:Grammar.Token.Bracket.Right           = try .init(parsing: &input),
                    _:Grammar.Token.Parenthesis.Left        = try .init(parsing: &input),
                    url:[NotClosingParenthesis]     =     .init(parsing: &input),
                    _:Grammar.Token.Parenthesis.Right       = try .init(parsing: &input)
                self.text       = .init(parsing: String.init(text.map(\.character)))
                self.url        = .init(url.map(\.character))
                self.classes    = []
            }
        }
        
        struct SymbolLink:Grammar.Parsable
        {
            struct Path:Grammar.Parsable
            {
                struct Label:Grammar.Parsable
                {
                    let string:String
                    
                    init(parsing input:inout Grammar.Input) throws
                    {
                        let identifier:Grammar.Identifier       = try .init(parsing: &input), 
                            variadic:Grammar.Token.Ellipsis?    =     .init(parsing: &input), 
                            _:Grammar.Token.Colon               = try .init(parsing: &input)
                        self.string     = "\(identifier.string)\(variadic == nil ? "" : "..."):"
                    }
                }
                
                let prefix:[String], 
                    path:[String], 
                    hint:String?
                    
                init(parsing input:inout Grammar.Input) throws 
                {
                    let start:String.Index              = input.index
                    let _:Grammar.Token.Backtick        = try .init(parsing: &input), 
                        prefix:
                        List<Grammar.Token.Parenthesis.Left, 
                        List<Grammar.Identifiers, 
                        List<Grammar.Token.Parenthesis.Right, 
                             Grammar.Token.Period>>>?           =     .init(parsing: &input)
                    // parse function/subscript first, or else it’s ambiguous 
                    if      let tail:List<Grammar.FunctionIdentifiers?, Grammar.Token.Parenthesis.Left> = 
                                                                      .init(parsing: &input) 
                    {
                        let labels:[Label]                      =     .init(parsing: &input) 
                        let _:Grammar.Token.Parenthesis.Right   = try .init(parsing: &input)
                        self.path = (tail.head?.prefix ?? []) + 
                            ["\(tail.head?.tail.string ?? "")(\(labels.map(\.string).joined()))"]
                    }
                    else if let tail:List<Grammar.Identifiers?, Grammar.Token.Bracket.Left> = 
                                                                      .init(parsing: &input) 
                    {
                        let labels:[Label]                      =     .init(parsing: &input) 
                        let _:Grammar.Token.Bracket.Right       = try .init(parsing: &input)
                        self.path = (tail.head?.identifiers ?? []) + 
                            ["[\(labels.map(\.string).joined())]"]
                    }
                    else if let tail:Grammar.Identifiers        =     .init(parsing: &input)
                    {
                        self.path = tail.identifiers
                    }
                    else 
                    {
                        throw input.expected(Self.self, from: start)
                    }
                    
                    // overload disambiguation 
                    if  let hint:
                            List<Grammar.Whitespace?, 
                            List<Grammar.Token.Hashtag, 
                            List<Grammar.Whitespace?, 
                            List<Grammar.Token.Parenthesis.Left, 
                            List<Grammar.Whitespace?, 
                            List<[Grammar.Token.Alphanumeric], 
                            List<Grammar.Whitespace?, 
                                Grammar.Token.Parenthesis.Right>>>>>>> = .init(parsing: &input) 
                    {
                        self.hint = .init(hint.body.body.body.body.body.head.map(\.character))
                    }
                    else 
                    {
                        self.hint = nil
                    }
                    
                    let _:Grammar.Token.Backtick    = try .init(parsing: &input)
                    self.prefix                     = prefix?.body.head.identifiers ?? []
                }
            }
            
            let paths:[Path], 
                suffix:[String]
            
            init(parsing input:inout Grammar.Input) throws 
            {
                let _:Grammar.Token.Bracket.Left                = try .init(parsing: &input),
                    head:Path                                   = try .init(parsing: &input), 
                    body:[Path]                                 =     .init(parsing: &input),
                    suffix:
                    [
                        List<Grammar.Identifier, Grammar.Token.Backtick>
                    ]                                           = .init(parsing: &input), 
                    _:Grammar.Token.Bracket.Right               = try .init(parsing: &input) 
                self.paths  = [head] + body
                self.suffix = suffix.map(\.head.string)
            }
        }
        
        struct InlineType:Grammar.Parsable
        {
            let type:Grammar.SwiftType 
            
            init(parsing input:inout Grammar.Input) throws 
            {
                let _:Grammar.Token.Bracket.Left    = try .init(parsing: &input),
                    _:Grammar.Token.Bracket.Left    = try .init(parsing: &input),
                    _:Grammar.Token.Backtick        = try .init(parsing: &input)
                self.type                           = try .init(parsing: &input)
                let _:Grammar.Token.Backtick        = try .init(parsing: &input),
                    _:Grammar.Token.Bracket.Right   = try .init(parsing: &input),
                    _:Grammar.Token.Bracket.Right   = try .init(parsing: &input) 
            }
        }
        
        case symbol(SymbolLink)
        case type(InlineType)
        
        case link(Link)
        case sub([Text])
        case sup([Text])
        case text(Text)
        
        case code(Declaration)
        
        init(parsing input:inout Grammar.Input) throws 
        {
            let start:String.Index          = input.index 
            if      let link:Link           = .init(parsing: &input) 
            {
                self = .link(link)
            }
            else if let symbol:SymbolLink   = .init(parsing: &input) 
            {
                self = .symbol(symbol)
            }
            else if let type:InlineType     = .init(parsing: &input) 
            {
                self = .type(type)
            }
            else if let sub:List<Tilde, List<[NotClosingTilde], Tilde>> = 
                .init(parsing: &input) 
            {
                self = .sub(.init(parsing: .init(sub.body.head.map(\.character))))
            }
            else if let sup:List<Ditto, List<[NotClosingDitto], Ditto>> = 
                .init(parsing: &input) 
            {
                self = .sup(.init(parsing: .init(sup.body.head.map(\.character))))
            }
            else if let text:Text = .init(parsing: &input) 
            {
                self = .text(text)
            }
            else 
            {
                throw input.expected(Self.self, from: start)
            }
        }
    }
    
    enum Notice:Grammar.Parsable 
    {
        private 
        struct Note:Grammar.Parsable.Terminal 
        {
            static 
            var token:String = "note"
        }
        private 
        struct Warning:Grammar.Parsable.Terminal 
        {
            static 
            var token:String = "warning"
        }
        private 
        struct Important:Grammar.Parsable.Terminal 
        {
            static 
            var token:String = "important"
        }
        
        case note 
        case warning 
        case important 
        
        init(parsing input:inout Grammar.Input) throws 
        {
            let start:String.Index          = input.index 
            let _:Grammar.Indent            = try .init(parsing: &input), 
                _:Grammar.Token.Angle.Right = try .init(parsing: &input), 
                _:Grammar.Whitespace?       =     .init(parsing: &input)
            if      let _:Important         =     .init(parsing: &input) 
            {
                self = .important
            }
            else if let _:Warning           =     .init(parsing: &input) 
            {
                self = .warning 
            }
            else if let _:Note              =     .init(parsing: &input) 
            {
                self = .note 
            }
            else 
            {
                throw input.expected(Self.self, from: start)
            }
            let _:Grammar.Whitespace?       =     .init(parsing: &input), 
                _:Grammar.Token.Colon       = try .init(parsing: &input),
                _:Grammar.Endline           = try .init(parsing: &input)
        }
    }
    
    struct CodeBlock:Grammar.Parsable
    {
        // syntax highlighting 
        enum TokenInfo 
        {
            case attribute
            case literal 
            case interpolation
            case punctuation
            case `operator`
            case keyword
            case pseudo
            case variable
            case symbol(Link)
            case comment
            case whitespace
        }
        
        enum Language:Grammar.Parsable
        {
            private 
            struct Swift:Grammar.Parsable.Terminal
            {
                static 
                let token:String = "swift"
            }
            case swift 
            case text 
            
            init(parsing input:inout Grammar.Input) throws 
            {
                let start:String.Index          = input.index 
                if      let _:Swift = .init(parsing: &input)
                {
                    self = .swift 
                }
                else 
                {
                    throw input.expected(Self.self, from: start)
                }
            }
        }
        
        let language:Language 
        let content:[(text:String, info:TokenInfo)] 
        
        init(language:Language, content:[(text:String, info:TokenInfo)])
        {
            self.language   = language 
            self.content    = content 
        }
        
        init(parsing input:inout Grammar.Input) throws 
        {
            let _:Grammar.Indent            = try .init(parsing: &input), 
                _:Grammar.Token.Backtick    = try .init(parsing: &input), 
                _:Grammar.Token.Backtick    = try .init(parsing: &input),
                _:Grammar.Token.Backtick    = try .init(parsing: &input),
                language:Language?          =     .init(parsing: &input),
                _:Grammar.Endline           = try .init(parsing: &input)
            
            var content:String = ""
            while true 
            {
                if  let _:
                        List<Grammar.Endline, 
                        List<Grammar.Indent, 
                        List<Grammar.Token.Backtick, 
                        List<Grammar.Token.Backtick, 
                        List<Grammar.Token.Backtick, Grammar.Endline>>>>> = 
                    .init(parsing: &input) 
                {
                    break 
                }
                else if let character:Character = input.next()
                {
                    content.append(character)
                }
                else 
                {
                    throw input.expected(Grammar.Endline.self)
                }
            }
            self.language   = language ?? .text 
            // remove 4 spaces of indentation
            self.content    = SwiftCode.highlight(code: content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map 
            {
                "\($0.prefix(4).drop(while: \.isWhitespace))\($0.dropFirst(4))"
            }
            .joined(separator: "\n"))
        }
        
        var isEmpty:Bool 
        {
            self.content.isEmpty
        }
    }
    
    
    case paragraph([Element], notice:Notice?)
    case code(block:CodeBlock)
    
    init(parsing string:String) 
    {
        self.init(parsing: string, notice: nil)
    }
    init(parsing string:String, notice:Notice?) 
    {
        var input:Grammar.Input = .init(string)
        self = .paragraph(.init(parsing: &input), notice: notice)
        if input.index != input.string.endIndex 
        {
            print("warning: unparsed trailing characters '\(input.string[input.index...])'") 
        }
    }
    
    /* init(parsing input:inout Grammar.Input) 
    {
        self = .paragraph(.init(parsing: &input), notice: nil)
    } */
    
    var isEmpty:Bool 
    {
        switch self 
        {
        case .paragraph(let elements, notice: _):   return elements.isEmpty 
        case .code(block: let block):               return block.isEmpty
        }
    }
    
    static 
    var empty:Self 
    {
        .paragraph([], notice: nil)
    }
}

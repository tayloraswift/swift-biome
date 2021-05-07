enum Markdown 
{
    struct Asterisk:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "*"
    } 
    struct Backtick:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "`"
    } 
    struct Tilde:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "~"
    } 
    struct Ditto:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "^"
    } 
    struct Backslash:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "\\"
    } 
    struct Newline:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "\\n"
    } 
    //  ParagraphGrammar.Token          ::= <ParagraphLink> 
    //                            | <ParagraphSymbolLink>
    //                            | <ParagraphSubscript>
    //                            | <ParagraphSuperscript>
    //                            | '***'
    //                            | '**'
    //                            | '*'
    //                            | .
    //  ParagraphSubscript      ::= '~' [^~] * '~'
    //  ParagraphSuperscript    ::= '^' [^\^] * '^'
    //  ParagraphInlineType     ::= '[[`' <Type> '`]]'
    //  ParagraphSymbolLink     ::= '[' <SymbolPath> <SymbolPath> * ( <Identifier> '`' ) * ']'
    //  SymbolPath              ::= '`' ( '(' <Identifiers> ').' ) ? <SymbolTail> '`'
    //  SymbolTail              ::= <Identifiers> ? '[' ( <FunctionLabel> ':' ) * ']'
    //                            | <Identifiers> ( '(' ( <FunctionLabel> ':' ) * ')' ) ?
    //  ParagraphLink           ::= '[' [^\]] * '](' [^\)] ')'
    struct NotClosingBracket:Grammar.Parseable.CharacterClass
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
    struct NotClosingParenthesis:Grammar.Parseable.CharacterClass
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
    struct NotClosingTilde:Grammar.Parseable.CharacterClass
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
    struct NotClosingDitto:Grammar.Parseable.CharacterClass
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
    
    enum Element:Grammar.Parseable
    {
        enum Text:Grammar.Parseable
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
                else if let backticks:List<Backtick, [Backtick]> = 
                    .init(parsing: &input) 
                {
                    self = .backtick(count: 1 + backticks.body.count)
                }
                // escape sequences 
                else if let _:List<Backslash, Asterisk> = 
                    .init(parsing: &input) 
                {
                    self = .wildcard("*")
                }
                else if let _:List<Backslash, Backtick> = 
                    .init(parsing: &input) 
                {
                    self = .wildcard("`")
                }
                else if let _:List<Backslash, Backslash> = 
                    .init(parsing: &input) 
                {
                    self = .wildcard("\\")
                }
                else if let _:List<Backslash, Grammar.Token.Space> = 
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
        
        struct Link:Grammar.Parseable
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
        
        struct SymbolLink:Grammar.Parseable
        {
            struct Path:Grammar.Parseable
            {
                let prefix:[String], 
                    path:[String]
                    
                init(parsing input:inout Grammar.Input) throws 
                {
                    let start:String.Index              = input.index
                    let _:Backtick                      = try .init(parsing: &input), 
                        prefix:
                        List<Grammar.Token.Parenthesis.Left, 
                        List<Grammar.Identifiers, 
                        List<Grammar.Token.Parenthesis.Right, 
                             Grammar.Token.Period>>>?           =     .init(parsing: &input)
                    // parse subscript first, or else it’s ambiguous 
                    if      let tail:
                                List<Grammar.Identifiers?, 
                                List<Grammar.Token.Bracket.Left, 
                                List<
                                [
                                    List<Grammar.FunctionField.Label, Grammar.Token.Colon>
                                ], 
                                Grammar.Token.Bracket.Right>>>  =     .init(parsing: &input)
                    {
                        self.path = (tail.head?.identifiers ?? []) + 
                            ["[\(tail.body.body.head.map(\.head.description).joined())]"]
                    }
                    else if let tail:Grammar.Identifiers = .init(parsing: &input) 
                    {
                        if  let labels:
                                List<Grammar.Token.Parenthesis.Left, 
                                List<
                                [
                                    List<Grammar.FunctionField.Label, Grammar.Token.Colon>
                                ], 
                                Grammar.Token.Parenthesis.Right>> =   .init(parsing: &input)
                        {
                            self.path = tail.identifiers.dropLast() + 
                                ["\(tail.identifiers[tail.identifiers.endIndex - 1])(\(labels.body.head.map(\.head.description).joined()))"]
                        }
                        else 
                        {
                            self.path = tail.identifiers
                        }
                        
                    }
                    else 
                    {
                        throw input.expected(Self.self, from: start)
                    }
                    
                    let _:Backtick  = try .init(parsing: &input)
                    self.prefix     = prefix?.body.head.identifiers ?? []
                }
            }
            
            let paths:[Path], 
                suffix:[String]
            
            init(parsing input:inout Grammar.Input) throws 
            {
                let _:Grammar.Token.Bracket.Left                = try .init(parsing: &input),
                    head:Path                                   = try .init(parsing: &input), 
                    body:[Path]                                 =     .init(parsing: &input),
                    suffix:[List<Grammar.Identifier, Backtick>] = .init(parsing: &input), 
                    _:Grammar.Token.Bracket.Right               = try .init(parsing: &input) 
                self.paths  = [head] + body
                self.suffix = suffix.map(\.head.string)
            }
        }
        
        struct InlineType:Grammar.Parseable
        {
            let type:Grammar.SwiftType 
            
            init(parsing input:inout Grammar.Input) throws 
            {
                let _:Grammar.Token.Bracket.Left    = try .init(parsing: &input),
                    _:Grammar.Token.Bracket.Left    = try .init(parsing: &input),
                    _:Backtick                      = try .init(parsing: &input)
                self.type                           = try .init(parsing: &input)
                let _:Backtick                      = try .init(parsing: &input),
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
        
        case code([Page.Declaration.Token])
        
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
}

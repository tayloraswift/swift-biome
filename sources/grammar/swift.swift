extension Grammar
{
    static 
    func isIdentifierHead(_ scalar:Unicode.Scalar) -> Bool 
    {
        switch scalar 
        {
        case    "a" ... "z", 
                "A" ... "Z",
                "_", 
                
                "\u{00A8}", "\u{00AA}", "\u{00AD}", "\u{00AF}", 
                "\u{00B2}" ... "\u{00B5}", "\u{00B7}" ... "\u{00BA}",
                
                "\u{00BC}" ... "\u{00BE}", "\u{00C0}" ... "\u{00D6}", 
                "\u{00D8}" ... "\u{00F6}", "\u{00F8}" ... "\u{00FF}",
                
                "\u{0100}" ... "\u{02FF}", "\u{0370}" ... "\u{167F}", "\u{1681}" ... "\u{180D}", "\u{180F}" ... "\u{1DBF}", 
                
                "\u{1E00}" ... "\u{1FFF}", 
                
                "\u{200B}" ... "\u{200D}", "\u{202A}" ... "\u{202E}", "\u{203F}" ... "\u{2040}", "\u{2054}", "\u{2060}" ... "\u{206F}",
                
                "\u{2070}" ... "\u{20CF}", "\u{2100}" ... "\u{218F}", "\u{2460}" ... "\u{24FF}", "\u{2776}" ... "\u{2793}",
                
                "\u{2C00}" ... "\u{2DFF}", "\u{2E80}" ... "\u{2FFF}",
                
                "\u{3004}" ... "\u{3007}", "\u{3021}" ... "\u{302F}", "\u{3031}" ... "\u{303F}", "\u{3040}" ... "\u{D7FF}",
                
                "\u{F900}" ... "\u{FD3D}", "\u{FD40}" ... "\u{FDCF}", "\u{FDF0}" ... "\u{FE1F}", "\u{FE30}" ... "\u{FE44}", 
                
                "\u{FE47}" ... "\u{FFFD}", 
                
                "\u{10000}" ... "\u{1FFFD}", "\u{20000}" ... "\u{2FFFD}", "\u{30000}" ... "\u{3FFFD}", "\u{40000}" ... "\u{4FFFD}", 
                
                "\u{50000}" ... "\u{5FFFD}", "\u{60000}" ... "\u{6FFFD}", "\u{70000}" ... "\u{7FFFD}", "\u{80000}" ... "\u{8FFFD}", 
                
                "\u{90000}" ... "\u{9FFFD}", "\u{A0000}" ... "\u{AFFFD}", "\u{B0000}" ... "\u{BFFFD}", "\u{C0000}" ... "\u{CFFFD}", 
                
                "\u{D0000}" ... "\u{DFFFD}", "\u{E0000}" ... "\u{EFFFD}"
                :
            return true 
        default:
            return false
        }
    }
    static 
    func isIdentifierScalar(_ scalar:Unicode.Scalar) -> Bool 
    {
        if isIdentifierHead(scalar) 
        {
            return true 
        }
        switch scalar 
        {
        case    "0" ... "9", 
                "\u{0300}" ... "\u{036F}", 
                "\u{1DC0}" ... "\u{1DFF}", 
                "\u{20D0}" ... "\u{20FF}", 
                "\u{FE20}" ... "\u{FE2F}"
                :
            return true 
        default:
            return false
        }
    }
    static 
    func isOperatorHead(_ scalar:Unicode.Scalar) -> Bool 
    {
        switch scalar 
        {
        case    "/", "=", "-", "+", "!", "*", "%", "<", ">", "&", "|", "^", "~", "?",
                "\u{00A1}" ... "\u{00A7}",
                "\u{00A9}", "\u{00AB}",
                "\u{00AC}", "\u{00AE}",
                "\u{00B0}" ... "\u{00B1}",
                "\u{00B6}", "\u{00BB}", "\u{00BF}", "\u{00D7}", "\u{00F7}",
                "\u{2016}" ... "\u{2017}",
                "\u{2020}" ... "\u{2027}",
                "\u{2030}" ... "\u{203E}",
                "\u{2041}" ... "\u{2053}",
                "\u{2055}" ... "\u{205E}",
                "\u{2190}" ... "\u{23FF}",
                "\u{2500}" ... "\u{2775}",
                "\u{2794}" ... "\u{2BFF}",
                "\u{2E00}" ... "\u{2E7F}",
                "\u{3001}" ... "\u{3003}",
                "\u{3008}" ... "\u{3020}",
                "\u{3030}"
                :
            return true 
        default:
            return false
        }
    }
    static 
    func isOperatorScalar(_ scalar:Unicode.Scalar) -> Bool 
    {
        if isOperatorHead(scalar) 
        {
            return true 
        }
        switch scalar 
        {
        case    "\u{0300}" ... "\u{036F}",
                "\u{1DC0}" ... "\u{1DFF}",
                "\u{20D0}" ... "\u{20FF}",
                "\u{FE00}" ... "\u{FE0F}",
                "\u{FE20}" ... "\u{FE2F}",
                "\u{E0100}" ... "\u{E01EF}"
                :
            return true 
        default:
            return false
        }
    }
    
    enum Token 
    {
    }
}

extension Grammar.Token 
{
    struct Wildcard:Grammar.Parseable.CharacterClass
    {
        let character:Character 
        
        init?(_ character:Character)
        {
            if character.isNewline 
            {
                return nil 
            }
            self.character = character
        }
    } 
    struct Alphanumeric:Grammar.Parseable.CharacterClass
    {
        let character:Character 
        
        init?(_ character:Character)
        {
            guard character.isLetter || character.isNumber || character == "-" 
            else 
            {
                return nil 
            }
            self.character = character
        }
    } 
    struct BalancedContent:Grammar.Parseable.CharacterClass
    {
        let character:Character 
        
        init?(_ character:Character)
        {
            guard  !character.isNewline,
                    character != "(", 
                    character != ")",
                    character != "[",
                    character != "]",
                    character != "{",
                    character != "}"
            else 
            {
                return nil 
            }
            self.character = character
        }
    } 
    struct ASCIIDigit:Grammar.Parseable.CharacterClass
    {
        let character:Character 
        
        init?(_ character:Character)
        {
            guard character.isWholeNumber, character.isASCII
            else 
            {
                return nil 
            }
            self.character = character
        }
    } 
    struct Darkspace:Grammar.Parseable.CharacterClass
    {
        let character:Character 
        
        init?(_ character:Character)
        {
            if character.isWhitespace
            {
                return nil 
            }
            self.character = character
        }
    } 
    struct Newline:Grammar.Parseable.CharacterClass
    {
        init?(_ character:Character)
        {
            guard character.isNewline
            else 
            {
                return nil
            }
        }
    }
    // does not include newlines 
    struct Space:Grammar.Parseable.CharacterClass
    {
        init?(_ character:Character)
        {
            guard character.isWhitespace, !character.isNewline
            else 
            {
                return nil 
            }
        }
    }
    enum Parenthesis 
    {
        struct Left:Grammar.Parseable.Terminal
        {
            static 
            let token:String = "("
        }
        struct Right:Grammar.Parseable.Terminal
        {
            static 
            let token:String = ")"
        }
    }
    enum Bracket 
    {
        struct Left:Grammar.Parseable.Terminal
        {
            static 
            let token:String = "["
        }
        struct Right:Grammar.Parseable.Terminal
        {
            static 
            let token:String = "]"
        }
    }
    enum Brace 
    {
        struct Left:Grammar.Parseable.Terminal
        {
            static 
            let token:String = "{"
        }
        struct Right:Grammar.Parseable.Terminal
        {
            static 
            let token:String = "}"
        }
    }
    enum Angle 
    {
        struct Left:Grammar.Parseable.Terminal
        {
            static 
            let token:String = "<"
        }
        struct Right:Grammar.Parseable.Terminal
        {
            static 
            let token:String = ">"
        }
    }
    struct Question:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "?"
    }
    struct Comma:Grammar.Parseable.Terminal
    {
        static 
        let token:String = ","
    }
    struct Period:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "."
    }
    struct Colon:Grammar.Parseable.Terminal
    {
        static 
        let token:String = ":"
    } 
    struct Equals:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "="
    } 
    struct At:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "@"
    } 
    struct Ampersand:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "&"
    } 
    struct Hyphen:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "-"
    } 
    struct Hashtag:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "#"
    } 
    struct EqualsEquals:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "=="
    } 
    struct Arrow:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "->"
    } 
    struct Ellipsis:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "..."
    } 
    
    struct Let:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "let"
    }
    struct Var:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "var"
    }
    struct Associatedtype:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "associatedtype"
    }
    struct Typealias:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "typealias"
    }
    struct Throws:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "throws"
    } 
    struct Rethrows:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "rethrows"
    } 
    struct Final:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "final"
    } 
    struct `Protocol`:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "protocol"
    }
    struct Class:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "class"
    }
    struct Struct:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "struct"
    }
    struct Enum:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "enum"
    }
    
    struct Static:Grammar.Parseable.Terminal 
    {
        static 
        let token:String = "static"
    }
    struct Init:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "init"
    }
    struct Func:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "func"
    }
    struct Subscript:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "subscript"
    }
    struct Mutating:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "mutating"
    }
    struct Case:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "case"
    }
    struct Indirect:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "indirect"
    }
    struct Get:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "get"
    }
    struct Nonmutating:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "nonmutating"
    }
    struct Set:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "set"
    }
    struct Where:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "where"
    }
    struct Override:Grammar.Parseable.Terminal
    {
        static 
        let token:String = "override"
    } 
    
    enum Identifier 
    {
        struct Head:Grammar.Parseable.CharacterClass
        {
            let character:Swift.Character 
            
            init?(_ character:Swift.Character)
            {
                guard   let first:Unicode.Scalar = character.unicodeScalars.first, 
                                                                    Grammar.isIdentifierHead(first), 
                    character.unicodeScalars.dropFirst().allSatisfy(Grammar.isIdentifierScalar(_:))
                else 
                {
                    return nil 
                }
                self.character = character
            }
        } 
        struct Character:Grammar.Parseable.CharacterClass
        {
            let character:Swift.Character 
            
            init?(_ character:Swift.Character)
            {
                guard character.unicodeScalars.allSatisfy(Grammar.isIdentifierScalar(_:))
                else 
                {
                    return nil 
                }
                self.character = character
            }
        } 
    }
    
    enum Operator 
    {
        struct Head:Grammar.Parseable.CharacterClass
        {
            let character:Swift.Character 
            
            init?(_ character:Swift.Character)
            {
                guard   let first:Unicode.Scalar = character.unicodeScalars.first, 
                                                                    Grammar.isOperatorHead(first), 
                    character.unicodeScalars.dropFirst().allSatisfy(Grammar.isOperatorScalar(_:))
                else 
                {
                    return nil 
                }
                self.character = character
            }
        } 
        struct Character:Grammar.Parseable.CharacterClass
        {
            let character:Swift.Character 
            
            init?(_ character:Swift.Character)
            {
                guard character.unicodeScalars.allSatisfy(Grammar.isOperatorScalar(_:))
                else 
                {
                    return nil 
                }
                self.character = character
            }
        } 
    }
}

extension Grammar 
{
    // Whitespace ::= ' ' ' ' *
    struct Whitespace:Parseable 
    {
        init(parsing input:inout Input) throws
        {
            let _:Token.Space   = try .init(parsing: &input),
                _:[Token.Space] =     .init(parsing: &input)
        }
    }
    
    // Identifier ::= <Swift Identifier Head> <Swift Identifier Character> *
    struct Identifier:Parseable, CustomStringConvertible
    {
        let string:String 
        
        init(parsing input:inout Input) throws
        {
            let head:Token.Identifier.Head          = try .init(parsing: &input),
                body:[Token.Identifier.Character]   =     .init(parsing: &input)
            self.string = "\(head.character)\(String.init(body.map(\.character)))"
        }
        
        var description:String 
        {
            self.string
        }
    }
    
    // Identifiers ::= <Identifier> ( '.' <Identifier> ) * ( '.' <EncapsulatedOperator> ) ?
    struct Identifiers:Parseable, CustomStringConvertible
    {
        let identifiers:[String]
            
        init(parsing input:inout Input) throws
        {
            let head:Identifier = try .init(parsing: &input)
            let body:[List<Token.Period, Identifier>] = 
                .init(parsing: &input)
            let `operator`:List<Token.Period, EncapsulatedOperator>? = 
                .init(parsing: &input)
            let operators:[String] 
            if let `operator`:String = `operator`.map(\.body)?.string 
            {
                operators = [`operator`]
            }
            else 
            {
                operators = []
            }
            
            self.identifiers = ([head] + body.map(\.body)).map(\.string) + operators
        }
        
        var description:String 
        {
            "\(self.identifiers.joined(separator: "."))"
        }
    }
    
    // Type                ::= <UnwrappedType> '?' *
    // UnwrappedType       ::= <NamedType>
    //                       | <CompoundType>
    //                       | <FunctionType>
    //                       | <CollectionType>
    //                       | <ProtocolCompositionType>
    // NamedType           ::= <TypeIdentifier> ( '.' <TypeIdentifier> ) *
    // TypeIdentifier      ::= <Identifier> <TypeArguments> ?
    // TypeArguments       ::= '<' <Whitespace> ? <Type> <Whitespace> ? ( ',' <Whitespace> ? <Type> <Whitespace> ? ) * '>'
    // CompoundType        ::= '(' <Whitespace> ? ( <LabeledType> <Whitespace> ? ( ',' <Whitespace> ? <LabeledType> <Whitespace> ? ) * ) ? ')'
    // LabeledType         ::= ( <Identifier> <Whitespace> ? ':' <Whitespace> ? ) ? <Type> 
    // FunctionType        ::= ( <Attribute> <Whitespace> ) * <FunctionParameters> <Whitespace> ? ( 'throws' <Whitespace> ? ) ? '->' <Whitespace> ? <Type>
    // FunctionParameters  ::= '(' <Whitespace> ? ( <FunctionParameter> <Whitespace> ? ( ',' <Whitespace> ? <FunctionParameter> <Whitespace> ? ) * ) ? ')'
    // FunctionParameter   ::= ( <Attribute> <Whitespace> ) ? ( 'inout' <Whitespace> ) ? <Type> ( <Whitespace> ? '...' ) ?
    // Attribute           ::= '@' <Identifier>
    // CollectionType      ::= '[' <Whitespace> ? <Type> <Whitespace> ? ( ':' <Whitespace> ? <Type> <Whitespace> ? ) ? ']' 
    
    // ProtocolCompositionType ::= <Identifiers> ( <Whitespace> ? '&' <Whitespace> ? <Identifiers> ) *
    
    enum SwiftType:Parseable, CustomStringConvertible
    {
        indirect
        case named([TypeIdentifier])
        indirect 
        case compound([LabeledType])
        indirect 
        case function(FunctionType) 
        
        case protocols([[String]])
        
        init(parsing input:inout Input) throws
        {
            let unwrapped:UnwrappedType     = try .init(parsing: &input), 
                optionals:[Token.Question]  =     .init(parsing: &input)
            var inner:Self 
            switch unwrapped 
            {
            case .named(let type):
                inner = .named(type.identifiers)
            case .compound(let type):
                inner = .compound(type.elements)
            case .function(let type):
                inner = .function(type)
            case .protocols(let type):
                inner = .protocols(type.protocols)
            case .collection(let type):
                if let value:Self = type.value 
                {
                    inner = .named(
                    [
                        .init("Swift",      generics: []), 
                        .init("Dictionary", generics: [type.key, value])
                    ])
                }
                else 
                {
                    inner = .named(
                    [
                        .init("Swift", generics: []), 
                        .init("Array", generics: [type.key])
                    ])
                }
            }
            for _ in optionals 
            {
                inner = .named(
                [
                    .init("Swift",    generics: []), 
                    .init("Optional", generics: [inner])
                ])
            }
            self = inner
        }
        
        var description:String 
        {
            switch self 
            {
            case .named(let identifiers):
                return "\(identifiers.map(String.init(describing:)).joined(separator: "."))"
            case .compound(let elements):
                return "(\(elements.map(String.init(describing:)).joined(separator: ", ")))"
            case .function(let type):
                return "\(type.attributes.map{ "\($0) " }.joined())(\(type.parameters.map(String.init(describing:)).joined(separator: ", ")))\(type.throws ? " throws" : "") -> \(type.return)"
            case .protocols(let protocols):
                return protocols.map{ $0.joined(separator: ".") }.joined(separator: " & ")
            }
        }
    }
    enum UnwrappedType:Parseable 
    {
        case named(NamedType)
        case compound(CompoundType)
        case function(FunctionType)
        case collection(CollectionType)
        case protocols(ProtocolCompositionType)
        
        init(parsing input:inout Input) throws
        {
            let start:String.Index      = input.index
            if      let type:NamedType  = .init(parsing: &input)
            {
                self = .named(type)
            }
            // must parse function types before compound types, because a function 
            // parameters list looks just like a tuple
            else if let type:FunctionType = .init(parsing: &input)
            {
                self = .function(type)
            }
            else if let type:CompoundType = .init(parsing: &input)
            {
                self = .compound(type)
            }
            else if let type:CollectionType = .init(parsing: &input)
            {
                self = .collection(type)
            }
            else if let type:ProtocolCompositionType = .init(parsing: &input)
            {
                self = .protocols(type)
            }
            else 
            {
                throw input.expected(Self.self, from: start)
            }
        }
    }
    struct ProtocolCompositionType:Parseable
    {
        let protocols:[[String]]
            
        init(parsing input:inout Input) throws
        {
            let head:Identifiers     = try .init(parsing: &input), 
                body:[List<Whitespace?, List<Token.Ampersand, List<Whitespace?, Identifiers>>>] =
                                                  .init(parsing: &input)
            self.protocols = [head.identifiers] + body.map(\.body.body.body.identifiers)
        }
    }
    struct NamedType:Parseable
    {
        let identifiers:[TypeIdentifier]
            
        init(parsing input:inout Input) throws
        {
            let head:TypeIdentifier = try .init(parsing: &input)
            let body:[List<Token.Period, TypeIdentifier>] = .init(parsing: &input)
            self.identifiers = [head] + body.map(\.body)
        }
        
    }
    struct TypeIdentifier:Parseable, CustomStringConvertible
    {
        let identifier:String
        let generics:[SwiftType]
        
        init(_ identifier:String, generics:[SwiftType])
        {
            self.identifier = identifier 
            self.generics   = generics 
        }
        
        init(parsing input:inout Input) throws
        {
            let identifier:Identifier    = try .init(parsing: &input), 
                generics:TypeArguments?  =     .init(parsing: &input)
            self.init(identifier.string, generics: generics?.types ?? [])
        }
        
        var description:String 
        {
            "\(self.identifier)\(self.generics.isEmpty ? "" : "<\(self.generics.map(String.init(describing:)).joined(separator: ", "))>")"
        }
    }
    struct TypeArguments:Parseable
    {
        let types:[SwiftType]
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Angle.Left  = try .init(parsing: &input), 
                _:Whitespace?       =     .init(parsing: &input),
                head:SwiftType      = try .init(parsing: &input), 
                _:Whitespace?       =     .init(parsing: &input),
                body:[List<Token.Comma, List<Whitespace?, List<SwiftType, Whitespace?>>>] = 
                                          .init(parsing: &input),
                _:Token.Angle.Right = try .init(parsing: &input)
            self.types = [head] + body.map(\.body.body.head)
        }
    }
    struct CompoundType:Parseable
    {
        let elements:[LabeledType]
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Parenthesis.Left    = try .init(parsing: &input), 
                _:Whitespace?               =     .init(parsing: &input), 
                types:List<LabeledType, List<Whitespace?, [List<Token.Comma, List<Whitespace?, List<LabeledType, Whitespace?>>>]>>? = 
                                                  .init(parsing: &input), 
                _:Token.Parenthesis.Right   = try .init(parsing: &input)
            self.elements = types.map{ [$0.head] + $0.body.body.map(\.body.body.head) } ?? []
        }
    }
    struct LabeledType:Parseable, CustomStringConvertible
    {
        let label:String?
        let type:SwiftType
        
        init(parsing input:inout Input) throws
        {
            let label:List<Identifier, List<Whitespace?, List<Token.Colon, Whitespace?>>>? = 
                                            .init(parsing: &input), 
                type:SwiftType = try .init(parsing: &input)
            self.label  = label?.head.string 
            self.type   = type
        }
        
        var description:String 
        {
            "\(self.label.map{ "\($0):" } ?? "")\(self.type)"
        }
    }
    struct FunctionType:Parseable
    {
        let attributes:[Attribute]
        let parameters:[FunctionParameter]
        let `throws`:Bool
        let `return`:SwiftType
        
        init(parsing input:inout Input) throws
        {
            let attributes:[List<Attribute, Whitespace>] = 
                                                  .init(parsing: &input),
                _:Token.Parenthesis.Left    = try .init(parsing: &input),
                _:Whitespace?               =     .init(parsing: &input),
                parameters:List<FunctionParameter, List<Whitespace?, [List<Token.Comma, List<Whitespace?, List<FunctionParameter, Whitespace?>>>]>>? = 
                                                  .init(parsing: &input), 
                _:Token.Parenthesis.Right   = try .init(parsing: &input),
                _:Whitespace?               =     .init(parsing: &input), 
                `throws`:List<Token.Throws, Whitespace?>? = 
                                                  .init(parsing: &input), 
                _:Token.Arrow               = try .init(parsing: &input), 
                _:Whitespace?               =     .init(parsing: &input), 
                `return`:SwiftType          = try .init(parsing: &input)
            self.attributes = attributes.map(\.head)
            self.parameters = parameters.map{ [$0.head] + $0.body.body.map(\.body.body.head) } ?? []
            self.throws     = `throws` != nil
            self.return     = `return`
        }
    }
    struct FunctionParameter:Parseable, CustomStringConvertible
    {
        struct Inout:Parseable.Terminal 
        {
            static 
            let token:String = "inout"
        }
        
        let attributes:[Attribute]
        let `inout`:Bool, 
            variadic:Bool 
        let type:SwiftType
        
        init(parsing input:inout Input) throws
        {
            let attributes:[List<Attribute, Whitespace>]    = 
                                                                  .init(parsing: &input), 
                `inout`:List<Inout, Whitespace>?            =     .init(parsing: &input), 
                type:SwiftType                              = try .init(parsing: &input),
                variadic:List<Whitespace?, Token.Ellipsis>? =     .init(parsing: &input) 
            self.attributes = attributes.map(\.head) 
            self.inout      = `inout`  != nil 
            self.variadic   = variadic != nil 
            self.type       = type
        }
        
        var description:String 
        {
            "\(self.attributes.map{ "\($0) " }.joined())\(self.inout ? "inout " : "")\(self.type)\(self.variadic ? "..." : "")"
        }
    }
    struct Attribute:Parseable, CustomStringConvertible
    {
        let identifier:String
        
        init(parsing input:inout Input) throws
        {
            let _:Token.At              = try .init(parsing: &input),
                identifier:Identifier   = try .init(parsing: &input)
            self.identifier = identifier.string
        }
        
        var description:String 
        {
            "@\(self.identifier)"
        }
    }
    struct CollectionType:Parseable 
    {
        let key:SwiftType, 
            value:SwiftType?
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Bracket.Left    = try .init(parsing: &input),
                _:Whitespace?           =     .init(parsing: &input),
                key:SwiftType           = try .init(parsing: &input), 
                _:Whitespace?           =     .init(parsing: &input),
                value:List<Token.Colon, List<Whitespace?, List<SwiftType, Whitespace?>>>? =
                                              .init(parsing: &input), 
                _:Token.Bracket.Right   = try .init(parsing: &input)
            self.key    = key
            self.value  = value?.body.body.head
        }
    }
}

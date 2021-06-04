extension Int:Grammar.Parsable 
{
    init(parsing input:inout Grammar.Input) throws 
    {
        let start:String.Index                      = input.index 
        let negative:Grammar.Token.Hyphen?          = .init(parsing: &input) 
        let characters:[Grammar.Token.ASCIIDigit]   = .init(parsing: &input) 
        guard let value:Int = Int.init(String.init(characters.map(\.character)))
        else 
        {
            throw input.expected(Self.self, from: start)
        }
        self = negative == nil ? value : -value 
    }
}
extension Grammar
{
    //  Endline                 ::= ' ' * '\n'
    struct Endline:Parsable 
    {
        init(parsing input:inout Input) throws
        {
            let _:[Token.Space] =     .init(parsing: &input),
                _:Token.Newline = try .init(parsing: &input)
        }
    }
    
    //  FrameworkField          ::= <FrameworkField.Keyword> <Whitespace> <Identifier> <Endline>
    //  FrameworkField.Keyword  ::= 'module'
    //                            | 'plugin'
    struct FrameworkField:Parsable 
    {
        enum Keyword 
        {
            struct Module:Parsable.Terminal 
            {
                static 
                let token:String = "module"
            }
            struct Plugin:Parsable.Terminal 
            {
                static 
                let token:String = "plugin"
            }
            
            case module 
            case plugin 
            
            init(parsing input:inout Input) throws 
            {
                let start:String.Index  = input.index 
                if      let _:Module    = .init(parsing: &input)
                {
                    self = .module
                }
                else if let _:Plugin    = .init(parsing: &input)
                {
                    self = .plugin 
                }
                else 
                {
                    throw input.expected(Self.self, from: start)
                }
            }
        }
        
        let keyword:Keyword 
        let identifier:String 
        
        init(parsing input:inout Input) throws 
        {
            self.keyword                = try .init(parsing: &input)
            let _:Whitespace            = try .init(parsing: &input),
                identifier:Identifier   = try .init(parsing: &input),
                _:Endline               = try .init(parsing: &input)
            self.identifier = identifier.string
        }
    }
    //  DependencyField         ::= 'import' <Whitespace> <Identifier> <Endline>
    //                            | 'import' <Whitespace> <DependencyField.Keyword> <Whitespace> 
    //                              <Identifier> '.' <Identifiers> <Endline>
    //  DependencyField.Keyword ::= 'protocol'
    //                            | 'class'
    //                            | 'struct'
    //                            | 'enum'
    //                            | 'typealias'
    enum DependencyField:Parsable 
    {
        // different from TypeField.Keyword
        enum Keyword:Parsable 
        {
            case `protocol` 
            case `class` 
            case `struct` 
            case `enum`
            case `typealias`
            
            init(parsing input:inout Input) throws
            {
                let start:String.Index          = input.index
                if      let _:Token.`Protocol`  = .init(parsing: &input)
                {
                    self = .protocol
                }
                else if let _:Token.Class       = .init(parsing: &input)
                {
                    self = .class 
                }
                else if let _:Token.Struct      = .init(parsing: &input)
                {
                    self = .struct
                }
                else if let _:Token.Enum        = .init(parsing: &input)
                {
                    self = .enum 
                }
                else if let _:Token.Typealias   = .init(parsing: &input)
                {
                    self = .typealias 
                }
                else 
                {
                    throw input.expected(Self.self, from: start)
                }
            }
        }
        
        case module(identifier:String)
        case type(keyword:Keyword, identifiers:[String])
        
        init(parsing input:inout Input) throws 
        {
            let _:Token.Import              = try .init(parsing: &input),
                _:Whitespace                = try .init(parsing: &input)
            if  let keyword:Keyword         =     .init(parsing: &input),
                let _:Whitespace            =     .init(parsing: &input)
            {
                let head:Identifier         = try .init(parsing: &input),
                    _:Token.Period          = try .init(parsing: &input),
                    body:Identifiers        = try .init(parsing: &input)
                self = .type(keyword: keyword, identifiers: [head.string] + body.identifiers)
            }
            else 
            {
                let identifier:Identifier   = try .init(parsing: &input)
                self = .module(identifier: identifier.string)
            }
            let _:Endline                   = try .init(parsing: &input)
        }
    }
    
    //  LexemeField             ::= ( <LexemeField.Keyword> <Whitespace> ) ? 
    //                              'operator' <Whitespace> <Operator> 
    //                              ( <Whitespace> ? ':' <Whitespace> ? <Identifier> ) ?
    //                              <Endline>
    struct LexemeField:Parsable 
    {
        enum Keyword:Parsable
        {
            case prefix 
            case infix 
            case postfix
            
            init(parsing input:inout Input) throws 
            {
                let start:String.Index      = input.index 
                if      let _:Token.Prefix  = .init(parsing: &input)
                {
                    self = .prefix
                }
                else if let _:Token.Infix   = .init(parsing: &input)
                {
                    self = .infix
                }
                else if let _:Token.Postfix = .init(parsing: &input)
                {
                    self = .postfix
                }
                else 
                {
                    throw input.expected(Self.self, from: start)
                }
            }
        }
        
        let keyword:Keyword
        let lexeme:String 
        let precedence:String?
        
        init(parsing input:inout Input) throws
        {
            let keyword:List<Keyword, Whitespace>?  =     .init(parsing: &input), 
                _:Token.Operator                    = try .init(parsing: &input), 
                _:Whitespace                        = try .init(parsing: &input), 
                lexeme:Operator                     = try .init(parsing: &input), 
                precedence:
                List<Whitespace?, 
                List<Token.Colon, 
                List<Whitespace?, Identifier>>>?    =     .init(parsing: &input), 
                _:Endline                           = try .init(parsing: &input)
            self.keyword    = keyword?.head ?? .infix
            self.lexeme     = lexeme.string 
            self.precedence = precedence?.body.body.body.string 
        }
    }
    
    //  FunctionIdentifiers     ::= ( <Identifier> '.' ) * '(' <Operator> ')'
    //                            | ( <Identifier> '.' ) * <Identifier>
    struct FunctionIdentifiers:Parsable 
    {
        enum Tail 
        {
            case alphanumeric(String)
            case `operator`(String)
            
            var string:String 
            {
                switch self 
                {
                case .alphanumeric(let string), .operator(let string):
                    return string 
                }
            }
        }
        
        let prefix:[String]
        let tail:Tail 
        
        init(parsing input:inout Input) throws
        {
            let start:String.Index = input.index 
            
            let prefix:[List<Identifier, Token.Period>] = .init(parsing: &input)
            self.prefix = prefix.map(\.head.string)
            
            if      let _:Token.Parenthesis.Left        = .init(parsing: &input), 
                    let inner:Operator                  = .init(parsing: &input),
                    let _:Token.Parenthesis.Right       = .init(parsing: &input) 
            {
                self.tail = .operator(inner.string)
            }
            else if let identifier:Identifier           = .init(parsing: &input)
            {
                self.tail = .alphanumeric(identifier.string)
            }
            else 
            {
                throw input.expected(Self.self, from: start)
            }
        }
    }
    
    //  FunctionField           ::= <FunctionField.Keyword> <Whitespace> <FunctionIdentifiers> <TypeParameters> ? '?' ? 
    //                              '(' ( <Identifier> ':' ) * ')' 
    //                              ( <Whitespace> <FunctionField.Throws> ) ? <Endline>
    //                            | 'case' <Whitespace> <FunctionIdentifiers> <Endline>
    //  FunctionField.Keyword   ::= 'init'
    //                            | 'required' <Whitespace> 'init'
    //                            | 'convenience' <Whitespace> 'init'
    //                            | 'func'
    //                            | 'mutating' <Whitespace> 'func'
    //                            | 'prefix' <Whitespace> 'func'
    //                            | 'postfix' <Whitespace> 'func'
    //                            | 'static' <Whitespace> 'func'
    //                            | 'static' <Whitespace> 'prefix' <Whitespace> 'func'
    //                            | 'static' <Whitespace> 'postfix' <Whitespace> 'func'
    //                            | 'case' 
    //                            | 'indirect' <Whitespace> 'case' 
    //  FunctionField.Throws    ::= 'throws' 
    //                            | 'rethrows'
    //  TypeParameters          ::= '<' <Whitespace> ? <Identifier> <Whitespace> ? 
    //                              ( ',' <Whitespace> ? <Identifier> <Whitespace> ? ) * '>'
    struct FunctionField:Parsable, CustomStringConvertible
    {
        enum Keyword:Parsable 
        {
            case `init` 
            case requiredInit
            case convenienceInit
            case `func` 
            case mutatingFunc
            case prefixFunc 
            case postfixFunc
            case staticFunc
            case staticPrefixFunc
            case staticPostfixFunc
            case `case`
            case indirectCase
            
            init(parsing input:inout Input) throws 
            {
                let start:String.Index      = input.index 
                if      let _:Token.Init    = .init(parsing: &input)
                {
                    self = .`init`
                }
                else if let _:List<Token.Required, List<Whitespace, Token.Init>> = 
                    .init(parsing: &input)
                {
                    self = .requiredInit
                }
                else if let _:List<Token.Convenience, List<Whitespace, Token.Init>> = 
                    .init(parsing: &input)
                {
                    self = .convenienceInit
                }
                else if let _:Token.Func    = .init(parsing: &input)
                {
                    self = .func
                }
                else if let _:List<Token.Mutating, List<Whitespace, Token.Func>> = 
                    .init(parsing: &input)
                {
                    self = .mutatingFunc
                }
                else if let _:List<Token.Prefix, List<Whitespace, Token.Func>> = 
                    .init(parsing: &input)
                {
                    self = .prefixFunc
                }
                else if let _:List<Token.Postfix, List<Whitespace, Token.Func>> = 
                    .init(parsing: &input)
                {
                    self = .postfixFunc
                }
                else if let _:List<Token.Static, List<Whitespace, Token.Func>> = 
                    .init(parsing: &input)
                {
                    self = .staticFunc
                }
                else if let _:
                        List<Token.Static, 
                        List<Whitespace, 
                        List<Token.Prefix, 
                        List<Whitespace, Token.Func>>>> = 
                    .init(parsing: &input)
                {
                    self = .staticPrefixFunc
                }
                else if let _:
                        List<Token.Static, 
                        List<Whitespace, 
                        List<Token.Postfix, 
                        List<Whitespace, Token.Func>>>> = 
                    .init(parsing: &input)
                {
                    self = .staticPostfixFunc
                }
                else if let _:Token.Case    = .init(parsing: &input)
                {
                    self = .case
                }
                else if let _:List<Token.Indirect, List<Whitespace, Token.Case>> = 
                    .init(parsing: &input)
                {
                    self = .indirectCase
                }
                else 
                {
                    throw input.expected(Self.self, from: start)
                }
            }
        }
        
        enum Throws:Parsable 
        {
            case `throws` 
            case `rethrows`
            
            init(parsing input:inout Input) throws
            {
                let start:String.Index          = input.index 
                if      let _:Token.Throws      = .init(parsing: &input)
                {
                    self = .throws
                }
                else if let _:Token.Rethrows    = .init(parsing: &input)
                {
                    self = .rethrows
                }
                else 
                {
                    throw input.expected(Self.self, from: start)
                }
            }
        }
        
        private 
        struct Normal:Parsable
        {
            let keyword:Keyword
            let identifiers:FunctionIdentifiers
            let generics:[String] 
            let failable:Bool
            let labels:[String]
            let `throws`:Throws?
            
            init(parsing input:inout Input) throws
            {
                self.keyword                            = try .init(parsing: &input) 
                let _:Whitespace                        = try .init(parsing: &input)
                self.identifiers                        = try .init(parsing: &input)
                let generics:TypeParameters?            =     .init(parsing: &input),
                    failable:Token.Question?            =     .init(parsing: &input),
                    _:Token.Parenthesis.Left            = try .init(parsing: &input),
                    labels:
                    [
                        List<Identifier, Token.Colon>
                    ]                                   =     .init(parsing: &input),
                    _:Token.Parenthesis.Right           = try .init(parsing: &input),
                    `throws`:List<Whitespace, Throws>?  =     .init(parsing: &input),
                    _:Endline                           = try .init(parsing: &input)
                self.generics       = generics?.identifiers ?? [] 
                self.failable       = failable != nil 
                self.labels         = labels.map(\.head.string)
                self.throws         = `throws`?.body
            }
        }
        private 
        struct UninhabitedCase:Parsable
        {
            let identifiers:FunctionIdentifiers
            
            init(parsing input:inout Input) throws
            {
                let _:Token.Case            = try .init(parsing: &input), 
                    _:Whitespace            = try .init(parsing: &input)
                self.identifiers            = try .init(parsing: &input)
                let _:Endline               = try .init(parsing: &input)
            }
        }
        
        let keyword:Keyword
        let identifiers:FunctionIdentifiers
        let generics:[String] 
        let failable:Bool
        let labels:[String]?
        let `throws`:Throws?
            
        init(parsing input:inout Input) throws 
        {
            let start:String.Index                  = input.index 
            if      let normal:Normal               = .init(parsing: &input) 
            {
                self.keyword        = normal.keyword 
                self.identifiers    = normal.identifiers 
                self.generics       = normal.generics
                self.failable       = normal.failable 
                self.labels         = normal.labels
                self.throws         = normal.throws
            }
            else if let uninhabited:UninhabitedCase = .init(parsing: &input) 
            {
                self.keyword        = .case
                self.identifiers    = uninhabited.identifiers 
                self.generics       = [] 
                self.failable       = false 
                self.labels         = nil
                self.throws         = nil
            }
            else 
            {
                throw input.expected(Self.self, from: start)
            }
        }
        
        var description:String 
        {
            """
            FunctionField
            {
                keyword     : \(self.keyword)
                identifiers : \(self.identifiers)
                generics    : \(self.generics)
                failable    : \(self.failable)
                labels      : \(self.labels ?? [])
                throws      : \(self.throws as Any)
            }
            """
        }
    }
    
    //  SubscriptField          ::= 'subscript' <Whitespace> <Identifiers> <TypeParameters> ? 
    //                              '[' ( <Identifier> ':' ) * ']' <Whitespace> ? <Accessors> <Endline> 
    struct SubscriptField:Parsable, CustomStringConvertible
    {
        let identifiers:[String],
            generics:[String],
            labels:[String], 
            accessors:Accessors
            
        init(parsing input:inout Input) throws
        {
            let _:Token.Subscript                       = try .init(parsing: &input), 
                _:Whitespace                            = try .init(parsing: &input),
                identifiers:Identifiers                 = try .init(parsing: &input),
                generics:TypeParameters?                =     .init(parsing: &input),
                _:Token.Bracket.Left                    = try .init(parsing: &input),
                labels:[List<Identifier, Token.Colon>]  =     .init(parsing: &input),
                _:Token.Bracket.Right                   = try .init(parsing: &input),
                _:Whitespace?                           =     .init(parsing: &input),
                accessors:Accessors                     = try .init(parsing: &input),
                _:Endline                               = try .init(parsing: &input)
            self.identifiers    = identifiers.identifiers 
            self.generics       = generics?.identifiers ?? [] 
            self.labels         = labels.map(\.head.string) 
            self.accessors      = accessors
        }
        
        var description:String 
        {
            """
            SubscriptField 
            {
                identifiers     : \(self.identifiers)
                labels          : \(self.labels)
                accessors       : \(self.accessors)
            }
            """
        }
    }
    
    struct TypeParameters:Parsable, CustomStringConvertible
    {
        let identifiers:[String]
            
        init(parsing input:inout Input) throws
        {
            let _:Token.Angle.Left  = try .init(parsing: &input), 
                _:Whitespace?       =     .init(parsing: &input),
                head:Identifier     = try .init(parsing: &input), 
                _:Whitespace?       =     .init(parsing: &input),
                body:[List<Token.Comma, List<Whitespace?, List<Identifier, Whitespace?>>>] = 
                .init(parsing: &input),
                _:Token.Angle.Right = try .init(parsing: &input)
            
            self.identifiers = ([head] + body.map(\.body.body.head)).map(\.string)
        }
        
        var description:String 
        {
            "<\(self.identifiers.joined(separator: ", "))>"
        }
    }
    
    //  PropertyField           ::= <PropertyField.Keyword> <Whitespace> <Identifiers> 
    //                              <Whitespace> ? ':' <Whitespace> ? <Type> 
    //                              ( <Whitespace> ? <MemberMutability> ) ? <Endline> 
    //  PropertyField.Keyword   ::= 'let'
    //                            | 'var'
    //                            | 'class' <Whitespace> 'var'
    //                            | 'static' <Whitespace> 'let'
    //                            | 'static' <Whitespace> 'var'
    //  Accessors               ::= '{' <Whitespace> ? 'get' 
    //                              ( ( <Whitespace> 'nonmutating' ) ? <Whitespace> 'set' ) ? <Whitespace> ? '}'
    struct PropertyField:Parsable, CustomStringConvertible
    {
        enum Keyword:Parsable 
        {
            case `let` 
            case `var` 
            case classVar
            case staticLet 
            case staticVar
            
            init(parsing input:inout Input) throws
            {
                let start:String.Index  = input.index 
                if      let _:Token.Let = .init(parsing: &input)
                {
                    self = .let
                }
                else if let _:Token.Var = .init(parsing: &input)
                {
                    self = .var 
                }
                else if let _:List<Token.Class, List<Whitespace, Token.Var>> = 
                    .init(parsing: &input)
                {
                    self = .classVar
                }
                else if let _:List<Token.Static, List<Whitespace, Token.Let>> = 
                    .init(parsing: &input)
                {
                    self = .staticLet 
                }
                else if let _:List<Token.Static, List<Whitespace, Token.Var>> = 
                    .init(parsing: &input)
                {
                    self = .staticVar
                }
                else 
                {
                    throw input.expected(Self.self, from: start)
                }
            }
        }
        
        let keyword:Keyword
        let identifiers:[String]
        let type:SwiftType
        let accessors:Accessors?
            
        init(parsing input:inout Input) throws
        {
            self.keyword                = try .init(parsing: &input) 
            let _:Whitespace            = try .init(parsing: &input),
                identifiers:Identifiers = try .init(parsing: &input),
                _:Whitespace?           =     .init(parsing: &input),
                _:Token.Colon           = try .init(parsing: &input),
                _:Whitespace?           =     .init(parsing: &input)
            self.type                   = try .init(parsing: &input)
            let accessors:List<Whitespace?, Accessors>? = 
                                              .init(parsing: &input),
                _:Grammar.Endline       = try .init(parsing: &input)
            self.identifiers    = identifiers.identifiers
            self.accessors      = accessors?.body
        }
        
        var description:String 
        {
            """
            PropertyField 
            {
                keyword     : \(self.keyword)
                identifiers : \(self.identifiers)
                type        : \(self.type)
                accessors   : \(self.accessors.map(String.init(describing:)) ?? "")
            }
            """
        }
    }

    enum Accessors:Parsable, CustomStringConvertible
    {
        case settable(nonmutating:Bool)
        case nonsettable
            
        init(parsing input:inout Input) throws
        {
            let _:Token.Brace.Left  = try .init(parsing: &input), 
                _:Whitespace?       =     .init(parsing: &input),
                _:Token.Get         = try .init(parsing: &input)
            if let set:List<List<Whitespace, Token.Nonmutating>?, List<Whitespace, Token.Set>> =
                                          .init(parsing: &input)
            {
                self = .settable(nonmutating: set.head != nil)
            }
            else 
            {
                self = .nonsettable
            }
            let _:Whitespace?       =     .init(parsing: &input),
                _:Token.Brace.Right = try .init(parsing: &input)
        }
        
        var description:String 
        {
            switch self 
            {
            case .nonsettable:                  return "{ get }"
            case .settable(nonmutating: true):  return "{ get nonmutating set }"
            case .settable(nonmutating: false): return "{ get set }"
            }
        }
    }
    
    //  TypealiasField          ::= 'typealias' <Whitespace> <Identifiers> <TypeParameters> ?
    //                              <Whitespace> ? '=' <Whitespace> ? <Type> <Endline>
    struct TypealiasField:Parsable, CustomStringConvertible 
    {
        let identifiers:[String]
        let generics:[String]
        let target:SwiftType
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Typealias           = try .init(parsing: &input),
                _:Whitespace                = try .init(parsing: &input), 
                identifiers:Identifiers     = try .init(parsing: &input), 
                generics:TypeParameters?    =     .init(parsing: &input),
                _:Whitespace?               =     .init(parsing: &input), 
                _:Token.Equals              = try .init(parsing: &input), 
                _:Whitespace?               =     .init(parsing: &input)
            self.target                     = try .init(parsing: &input) 
            let _:Endline                   = try .init(parsing: &input)
            self.identifiers    = identifiers.identifiers 
            self.generics       = generics?.identifiers ?? []
        }
        
        var description:String 
        {
            """
            TypealiasField 
            {
                identifiers : \(self.identifiers)
                generics    : \(self.generics)
                target      : \(self.target)
            }
            """
        }
    }
    //  AssociatedtypeField     ::= 'associatedtype' <Whitespace> <Identifiers> 
    //                              ( <Whitespace> ? '=' <Whitespace> ? <Type> ) ? <Endline>
    struct AssociatedtypeField:Parsable, CustomStringConvertible
    {
        let identifiers:[String]
        let target:SwiftType?
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Associatedtype          = try .init(parsing: &input),
                _:Whitespace                    = try .init(parsing: &input), 
                identifiers:Identifiers         = try .init(parsing: &input), 
                target:
                List<Whitespace?, 
                List<Token.Equals, 
                List<Whitespace?, SwiftType>>>? =     .init(parsing: &input),
                _:Endline                       = try .init(parsing: &input)
            self.identifiers    = identifiers.identifiers 
            self.target         = target?.body.body.body
        }
        
        var description:String 
        {
            """
            AssociatedtypeField 
            {
                identifiers : \(self.identifiers)
                target      : \(self.target as Any)
            }
            """
        }
    }
    //  TypeField               ::= <TypeField.Keyword> <Whitespace> <Identifiers> <TypeParameters> ? <Endline>
    //  TypeField.Keyword       ::= 'protocol'
    //                            | 'class'
    //                            | 'struct'
    //                            | 'enum'
    //                            | 'extension'
    struct TypeField:Parsable, CustomStringConvertible
    {
        enum Keyword:Parsable 
        {
            case `protocol` 
            case `class` 
            case `struct` 
            case `enum`
            case `extension`
            
            init(parsing input:inout Input) throws
            {
                let start:String.Index              = input.index
                if      let _:Token.`Protocol`      = .init(parsing: &input)
                {
                    self = .protocol
                }
                else if let _:Token.Class           = .init(parsing: &input)
                {
                    self = .class 
                }
                else if let _:Token.Struct          = .init(parsing: &input)
                {
                    self = .struct
                }
                else if let _:Token.Enum            = .init(parsing: &input)
                {
                    self = .enum 
                }
                else if let _:Token.Extension       = .init(parsing: &input)
                {
                    self = .extension 
                }
                else 
                {
                    throw input.expected(Self.self, from: start)
                }
            }
        }
        
        let keyword:Keyword 
        let identifiers:[String]
        let generics:[String]
        
        init(parsing input:inout Input) throws
        {
            self.keyword                    = try .init(parsing: &input) 
            let _:Whitespace                = try .init(parsing: &input), 
                identifiers:Identifiers     = try .init(parsing: &input), 
                generics:TypeParameters?    =     .init(parsing: &input),
                _:Endline                   = try .init(parsing: &input)
            self.identifiers    = identifiers.identifiers 
            self.generics       = generics?.identifiers ?? []
        }
        
        var description:String 
        {
            """
            TypeField 
            {
                keyword     : \(self.keyword)
                identifiers : \(self.identifiers)
                generics    : \(self.generics)
            }
            """
        }
    }
    
    // different from ProtocolCompositionType because it can accept a single 
    // protocol by itself
    struct Protocols:Parsable
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
    
    //  ConformanceField        ::= ':' <Whitespace> ? <Protocols> 
    //                              ( <Whitespace> <WhereClauses> ) ? <Endline>
    struct ConformanceField:Parsable, CustomStringConvertible
    {
        let conformances:[[String]]
        let conditions:[WhereClause]
        
        // used by standard library importer
        init(conformances:[[String]], conditions:[WhereClause])
        {
            self.conformances   = conformances
            self.conditions     = conditions
        }
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Colon                               = try .init(parsing: &input), 
                _:Whitespace?                               =     .init(parsing: &input), 
                conformances:Protocols                      = try .init(parsing: &input), 
                conditions:List<Whitespace, WhereClauses>?  =     .init(parsing: &input),
                _:Endline                                   = try .init(parsing: &input)
            self.conformances   = conformances.protocols
            self.conditions     = conditions?.body.clauses ?? []
        }
        
        var description:String 
        {
            """
            ConformanceField 
            {
                conformances  : \(self.conformances)
                conditions    : \(self.conditions)
            }
            """
        }
    }
    
    //  ImplementationField     ::= '?:' <Whitespace> ? <Protocols> 
    //                              ( <Whitespace> <WhereClauses> ) ? <Endline>
    //                            | '?' <Whitespace> ? <WhereClauses> <Endline>
    struct ImplementationField:Parsable 
    {
        let conformances:[[String]]
        let conditions:[WhereClause]
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Question                                = try .init(parsing: &input)
            if  let _:Token.Colon                               =     .init(parsing: &input) 
            {
                let _:Whitespace?                               =     .init(parsing: &input), 
                    conformances:Protocols                      = try .init(parsing: &input), 
                    conditions:List<Whitespace, WhereClauses>?  =     .init(parsing: &input)
                self.conformances   = conformances.protocols
                self.conditions     = conditions?.body.clauses ?? []
            }
            else 
            {
                let _:Whitespace?                               =     .init(parsing: &input), 
                    conditions:WhereClauses                     = try .init(parsing: &input)
                self.conformances   = [] 
                self.conditions     = conditions.clauses 
            }
            let _:Endline                                           = try .init(parsing: &input)
        }
    }
    
    //  ConstraintsField        ::= <WhereClauses> <Endline>
    //  WhereClauses            ::= 'where' <Whitespace> <WhereClause> 
    //                              ( <Whitespace> ? ',' <Whitespace> ? <WhereClause> ) * 
    //  WhereClause             ::= <Identifiers> <Whitespace> ? <WherePredicate>
    //  WherePredicate          ::= ':' <Whitespace> ? <Protocols> 
    //                            | '==' <Whitespace> ? <Type>
    struct ConstraintsField:Parsable, CustomStringConvertible
    {
        let clauses:[WhereClause]
        
        // used by standard library importer
        init(clauses:[WhereClause])
        {
            self.clauses = clauses
        }
        
        init(parsing input:inout Input) throws
        {
            let clauses:WhereClauses    = try .init(parsing: &input), 
                _:Endline               = try .init(parsing: &input)
            self.clauses = clauses.clauses
        }
        
        var description:String 
        {
            """
            ConstraintsField 
            {
                constraint  : \(self.clauses.map(\.description).joined(separator: ", "))
            }
            """
        }
    }
    struct WhereClauses:Parsable 
    {    
        let clauses:[WhereClause]
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Where       = try .init(parsing: &input), 
                _:Whitespace        = try .init(parsing: &input), 
                head:WhereClause    = try .init(parsing: &input),
                body:[List<Whitespace?, List<Token.Comma, List<Whitespace?, WhereClause>>>] = 
                                          .init(parsing: &input)
            self.clauses = [head] + body.map(\.body.body.body)
        }
    }
    struct WhereClause:Parsable, CustomStringConvertible
    {
        let subject:[String], 
            predicate:WherePredicate 
            
        init(parsing input:inout Input) throws
        {
            let subject:Identifiers     = try .init(parsing: &input), 
                _:Whitespace?           =     .init(parsing: &input) 
            self.predicate              = try .init(parsing: &input)
            self.subject                = subject.identifiers
        }
        
        var description:String 
        {
            switch self.predicate  
            {
            case .conforms(let protocols):
                return "\(self.subject.joined(separator: ".")):\(protocols.map{ $0.joined(separator: ".") }.joined(separator: " & "))"
            case .equals(let type):
                return "\(self.subject.joined(separator: ".")) == \(type)"
            }
        }
    }
    enum WherePredicate:Parsable
    {
        case conforms([[String]]) 
        case equals(SwiftType) 
        
        init(parsing input:inout Input) throws
        {
            let start:String.Index = input.index 
            if      let _:List<Token.Colon, Whitespace?> = 
                .init(parsing: &input), 
                    let protocols:Protocols = 
                .init(parsing: &input)
            {
                self = .conforms(protocols.protocols)
            }
            else if let _:List<Token.EqualsEquals, Whitespace?> = 
                .init(parsing: &input), 
                    let type:SwiftType = 
                .init(parsing: &input)
            {
                self = .equals(type)
            }
            else 
            {
                throw input.expected(Self.self, from: start)
            }
        }
    }
    
    //  AttributeField          ::= '@' <Whitespace> ? <DeclarationAttribute> <Endline>
    //  DeclarationAttribute    ::= 'frozen'
    //                            | 'inlinable'
    //                            | 'discardableResult'
    //                            | 'resultBuilder'
    //                            | 'propertyWrapper'
    //                            | 'specialized' <Whitespace> <WhereClauses>
    //                            | ':'  <Whitespace> ? <Type>
    enum AttributeField:Parsable
    {
        private 
        struct Frozen:Parsable.Terminal 
        {
            static 
            let token:String = "frozen"
        }
        private 
        struct Inlinable:Parsable.Terminal 
        {
            static 
            let token:String = "inlinable"
        }
        private 
        struct DiscardableResult:Parsable.Terminal 
        {
            static 
            let token:String = "discardableResult"
        }
        private 
        struct ResultBuilder:Parsable.Terminal 
        {
            static 
            let token:String = "resultBuilder"
        }
        private 
        struct PropertyWrapper:Parsable.Terminal 
        {
            static 
            let token:String = "propertyWrapper"
        }
        private 
        struct Specialized:Parsable.Terminal 
        {
            static 
            let token:String = "specialized"
        }
        
        case frozen 
        case inlinable 
        case discardableResult 
        case resultBuilder
        case propertyWrapper
        case specialized([WhereClause])
        case custom(SwiftType)
        
        init(parsing input:inout Input) throws
        {
            let start:String.Index  = input.index 
            let _:Token.At          = try .init(parsing: &input), 
                _:Whitespace?       =     .init(parsing: &input)
            
            if      let _:List<Frozen, Endline> = .init(parsing: &input)
            {
                self = .frozen
            }
            else if let _:List<Inlinable, Endline> = .init(parsing: &input)
            {
                self = .inlinable 
            }
            else if let _:List<DiscardableResult, Endline> = .init(parsing: &input)
            {
                self = .discardableResult
            }
            else if let _:List<ResultBuilder, Endline> = .init(parsing: &input)
            {
                self = .resultBuilder
            }
            else if let _:List<PropertyWrapper, Endline> = 
                .init(parsing: &input)
            {
                self = .propertyWrapper
            }
            else if let specialized:List<Specialized, List<Whitespace, List<WhereClauses, Endline>>> = 
                .init(parsing: &input)
            {
                self = .specialized(specialized.body.body.head.clauses)
            }
            else if let custom:List<Token.Colon, List<Whitespace?, List<SwiftType, Endline>>> = 
                .init(parsing: &input)
            {
                self = .custom(custom.body.body.head) 
            }
            else 
            {
                throw input.expected(Self.self, from: start)
            }
        }
    }
    
    //  ParameterField          ::= '-' <Whitespace> ? <ParameterName> <Whitespace> ? 
    //                              ':' <Whitespace> ? <FunctionParameter> <Endline>
    //  ParameterName           ::= <Identifier> 
    //                            | '->'
    struct ParameterField:Parsable, CustomStringConvertible
    {
        let name:ParameterName 
        let parameter:FunctionParameter 
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Hyphen              = try .init(parsing: &input), 
                _:Whitespace?               =     .init(parsing: &input), 
                name:ParameterName          = try .init(parsing: &input), 
                _:Whitespace?               =     .init(parsing: &input), 
                _:Token.Colon               = try .init(parsing: &input),
                _:Whitespace?               =     .init(parsing: &input), 
                parameter:FunctionParameter = try .init(parsing: &input), 
                _:Endline                   = try .init(parsing: &input)
            self.name       = name
            self.parameter  = parameter
        }
        
        var description:String 
        {
            """
            ParameterField 
            {
                name        : \(self.name)
                parameter   : \(self.parameter)
            }
            """
        }
    }
    enum ParameterName:Parsable
    {
        case parameter(String) 
        case `return`
        
        init(parsing input:inout Input) throws
        {
            let start:String.Index              = input.index 
            if      let identifier:Identifier   = .init(parsing: &input)
            {
                self = .parameter(identifier.string)
            }
            else if let _:Token.Arrow = .init(parsing: &input)
            {
                self = .return
            }
            else 
            {
                throw input.expected(Self.self, from: start)
            }
        }
    }
    
    //  DispatchField           ::= <DispatchField.Keyword> ( <Whitespace> <DispatchField.Keyword> ) * <Endline>
    struct DispatchField:Parsable 
    {
        enum Keyword:Parsable, Hashable, CaseIterable 
        {
            case `final`
            case `override`
            
            init(parsing input:inout Input) throws
            {
                let start:String.Index          = input.index 
                if      let _:Token.Final       = .init(parsing: &input)
                {
                    self = .final
                }
                else if let _:Token.Override    = .init(parsing: &input)
                {
                    self = .override 
                }
                else 
                {
                    throw input.expected(Self.self, from: start)
                }
            }
        }
        
        let keywords:Set<Keyword>
        
        init(parsing input:inout Input) throws
        {
            let head:Keyword                        = try .init(parsing: &input), 
                body:[List<Whitespace, Keyword>]    =     .init(parsing: &input), 
                _:Endline                           = try .init(parsing: &input)
            self.keywords = .init([head] + body.map(\.body))
        }
    }
    
    //  RequirementField        ::= 'required' <Endline>
    //                            | 'defaulted' ( <Whitespace> <WhereClauses> ) ? <Endline>
    enum RequirementField:Parsable 
    {
        private 
        struct Required:Parsable.Terminal 
        {
            static 
            let token:String = "required"
        }
        private 
        struct Defaulted:Parsable.Terminal 
        {
            static 
            let token:String = "defaulted"
        }
        
        case required
        case defaulted([WhereClause])
        
        init(parsing input:inout Input) throws
        {
            let start:String.Index                  = input.index 
            if      let _:List<Required, Endline>   = .init(parsing: &input)
            {
                self = .required
                return 
            }
            else if let _:Defaulted = .init(parsing: &input)
            {
                let conditions:List<Whitespace, WhereClauses>? = 
                    .init(parsing: &input) 
                if let _:Endline = .init(parsing: &input) 
                {
                    self = .defaulted(conditions?.body.clauses ?? [])
                    return
                }
            }
            throw input.expected(Self.self, from: start)
        }
    }
    
    //  TopicKey                ::= [a-zA-Z0-9\-] *
    //  TopicField              ::= '#' <Whitespace> ? '[' <BalancedToken> * ']' <Whitespace> ? 
    //                              '(' <Whitespace> ? <TopicKey> 
    //                              ( <Whitespace> ? ',' <Whitespace> ? <TopicKey> ) * <Whitespace> ? ')' <Endline>
    //  TopicMembershipField    ::= '#' <Whitespace> ? '(' <Whitespace> ? 
    //                              ( <Integer Literal> <Whitespace> ? ':' <Whitespace> ? ) ? 
    //                              <TopicKey> <Whitespace> ? ')' <Endline>
    struct TopicField:Parsable 
    {
        let display:String, 
            keys:[String] 
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Hashtag                 = try .init(parsing: &input), 
                _:Whitespace?                   =     .init(parsing: &input), 
                _:Token.Bracket.Left            = try .init(parsing: &input), 
                display:[BalancedToken]         =     .init(parsing: &input), 
                _:Token.Bracket.Right           = try .init(parsing: &input), 
                _:Token.Parenthesis.Left        = try .init(parsing: &input), 
                _:Whitespace?                   =     .init(parsing: &input), 
                head:[Token.Alphanumeric]       =     .init(parsing: &input), 
                body:[List<Whitespace?, List<Token.Comma, List<Whitespace?, [Token.Alphanumeric]>>>] =     
                                                      .init(parsing: &input), 
                _:Whitespace?                   =     .init(parsing: &input), 
                _:Token.Parenthesis.Right       = try .init(parsing: &input), 
                _:Endline                       = try .init(parsing: &input) 
            self.keys = 
                [.init(head.map(\.character))] 
                + 
                body.map(\.body.body.body).map{ .init($0.map(\.character)) }
            self.display = display.map(\.string).joined()
        }
    }
    struct TopicMembershipField:Parsable
    {
        let key:String?
        let rank:Int?
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Hashtag             = try .init(parsing: &input), 
                _:Whitespace?               =     .init(parsing: &input), 
                _:Token.Parenthesis.Left    = try .init(parsing: &input), 
                _:Whitespace?               =     .init(parsing: &input) 
            if let rank:List<Int, List<Whitespace?, List<Token.Colon, Whitespace?>>> = 
                                                  .init(parsing: &input)
            {
                self.rank = rank.head
            }
            else 
            {
                self.rank = nil 
            }
            let key:[Token.Alphanumeric]    =     .init(parsing: &input), 
                _:Whitespace?               =     .init(parsing: &input), 
                _:Token.Parenthesis.Right   = try .init(parsing: &input), 
                _:Endline                   = try .init(parsing: &input)
            
            self.key = key.isEmpty ? nil : String.init(key.map(\.character))
        }
    }
    
    //  ParagraphField          ::= <EmptyLines> ? <ParagraphField.Element> <EmptyLines> ? 
    //                              ( <ParagraphField.Element> <EmptyLines> ? ) * 
    //  EmptyLines              ::= <Endline> <Endline> *
    //  ParagraphField.Element  ::= <CodeBlock>
    //                            | <Notice>
    //                            | <NonEmptyLine>
    //
    //  Indent                  ::= '    ' 
    //  CodeBlock               ::= <Indent> '```' <Language> ? <Endline> . * <Endline> 
    //                              <Indent> '```' <Endline>
    //  Language                ::= 'swift'
    //  NonEmptyLine            ::= <Indent> <Whitespace> ? [^\s] . * '\n'
    //  Notice                  ::= <Indent> '>' <Whitespace> ? <Notice.Keyword> <Whitespace> ? 
    //                              ':' <Endline>
    //  Notice.Keyword          ::= 'note'
    //                            | 'warning'
    struct Indent:Parsable.Terminal
    {
        static 
        let token:String = "    "
    }
    struct ParagraphField:Parsable
    {
        private 
        struct EmptyLines:Parsable 
        {
            init(parsing input:inout Input) throws
            {
                let _:Endline   = try .init(parsing: &input), 
                    _:[Endline] =     .init(parsing: &input)
            }
        }
        private 
        struct NonEmptyLine:Parsable 
        {
            let string:String 
            
            init(parsing input:inout Input) throws
            {
                let _:Indent                = try .init(parsing: &input), 
                    _:Whitespace?           =     .init(parsing: &input), 
                    head:Token.Darkspace    = try .init(parsing: &input), 
                    body:[Token.Wildcard]   =     .init(parsing: &input), 
                    _:Token.Newline         = try .init(parsing: &input)
                var string:String = .init([head.character] + body.map(\.character))
                // trim trailing whitespace
                while let last:Character = string.last, last.isWhitespace
                {
                    string.removeLast()
                }
                self.string = string 
            }
        }
        private 
        enum Element:Parsable
        {
            case code(Paragraph.CodeBlock)
            case notice(Paragraph.Notice)
            case line(String)
            
            init(parsing input:inout Input) throws
            {
                // parse code block first, then notice, then line else it’s ambiguous 
                let start:String.Index                  = input.index 
                if      let block:Paragraph.CodeBlock   = .init(parsing: &input)
                {
                    self = .code(block)
                }
                else if let notice:Paragraph.Notice     = .init(parsing: &input) 
                {
                    self = .notice(notice)
                }
                else if let line:NonEmptyLine           = .init(parsing: &input) 
                {
                    self = .line(line.string)
                }
                else 
                {
                    throw input.expected(Self.self, from: start)
                }
            }
        }
        
        let paragraphs:[Paragraph]
        
        init(parsing input:inout Input) throws
        {
            let _:EmptyLines?                       =     .init(parsing: &input), 
                head:List<Element, EmptyLines?>     = try .init(parsing: &input), 
                body:[List<Element, EmptyLines?>]   =     .init(parsing: &input)
            
            let elements:[Element?] = ([head] + body).flatMap 
            {
                (element:List<Element, EmptyLines?>) -> [Element?] in 
                if let _:EmptyLines = element.body 
                {
                    return [element.head, nil]
                }
                else 
                {
                    return [element.head]
                }
            }
            
            var notice:Paragraph.Notice?    = nil 
            var lines:[String]              = []
            var paragraphs:[Paragraph]      = []
            for element:Element? in elements 
            {
                guard case .line(let line)? = element 
                else 
                {
                    if !lines.isEmpty
                    {
                        paragraphs.append(.init(parsing: lines.joined(separator: " "), 
                            notice: notice))
                        notice  = nil 
                        lines   = []
                    }
                    switch element 
                    {
                    case .notice(let next):
                        notice = next 
                    case .code(let block):
                        paragraphs.append(.code(block: block))
                    case .line:
                        fatalError("unreachable")
                    case nil:
                        break 
                    }
                    continue 
                }
                
                lines.append(line)
            }
            if !lines.isEmpty
            {
                paragraphs.append(.init(parsing: lines.joined(separator: " "), 
                    notice: notice))
            }
            
            self.paragraphs = paragraphs
        }
    }
    
    //  Field                   ::= <FrameworkField>
    //                            | <AssociatedtypeField>
    //                            | <AttributeField>
    //                            | <ConformanceField>
    //                            | <ConstraintsField>
    //                            | <DispatchField>
    //                            | <ImplementationField>
    //                            | <FunctionField>
    //                            | <LexemeField>
    //                            | <ParameterField>
    //                            | <PropertyField>
    //                            | <RequirementField>
    //                            | <SubscriptField>
    //                            | <TopicField>
    //                            | <TopicMembershipField>
    //                            | <TypealiasField>
    //                            | <TypeField>
    //                            | <ParagraphField>
    //                            | <Separator>
    //  Separator               ::= <Endline>
    enum HeaderField:Parsable 
    {
        case framework(FrameworkField) 
        case dependency(DependencyField) 
        case lexeme(LexemeField) 
        
        case `subscript`(SubscriptField) 
        case function(FunctionField) 
        case property(PropertyField) 
        case `associatedtype`(AssociatedtypeField) 
        case `typealias`(TypealiasField) 
        case type(TypeField) 
        
        init(parsing input:inout Input) throws
        {
            let start:String.Index = input.index 
            if      let field:FrameworkField = .init(parsing: &input)
            {
                self = .framework(field)
            }
            else if let field:DependencyField = .init(parsing: &input)
            {
                self = .dependency(field)
            }
            else if let field:LexemeField = .init(parsing: &input)
            {
                self = .lexeme(field)
            }
            else if let field:FunctionField = .init(parsing: &input)
            {
                self = .function(field)
            }
            else if let field:SubscriptField = .init(parsing: &input)
            {
                self = .subscript(field)
            }
            else if let field:PropertyField = .init(parsing: &input)
            {
                self = .property(field)
            }
            else if let field:AssociatedtypeField = .init(parsing: &input)
            {
                self = .associatedtype(field)
            }
            else if let field:TypealiasField = .init(parsing: &input)
            {
                self = .typealias(field)
            }
            else if let field:TypeField = .init(parsing: &input)
            {
                self = .type(field)
            }
            else 
            {
                throw input.expected(Self.self, from: start)
            }
        }
    }
    enum AuxillaryField:Parsable 
    {
        case attribute(AttributeField) 
        case conformance(ConformanceField) 
        case constraints(ConstraintsField) 
        case dispatch(DispatchField) 
        case implementation(ImplementationField) 
        case parameter(ParameterField) 
        case requirement(RequirementField) 
        
        case topic(TopicField)
        case topicMembership(TopicMembershipField)
        
        case paragraph(ParagraphField) 
        case separator
        
        init(parsing input:inout Input) throws
        {
            let start:String.Index = input.index 
            if      let field:ImplementationField = .init(parsing: &input)
            {
                self = .implementation(field)
            }
            else if let field:ConformanceField = .init(parsing: &input)
            {
                self = .conformance(field)
            }
            else if let field:ConstraintsField = .init(parsing: &input)
            {
                self = .constraints(field)
            }
            else if let field:AttributeField = .init(parsing: &input)
            {
                self = .attribute(field)
            }
            else if let field:DispatchField = .init(parsing: &input)
            {
                self = .dispatch(field)
            }
            else if let field:RequirementField = .init(parsing: &input)
            {
                self = .requirement(field)
            }
            else if let field:ParameterField = .init(parsing: &input)
            {
                self = .parameter(field)
            }
            else if let field:TopicField = .init(parsing: &input)
            {
                self = .topic(field)
            }
            else if let field:TopicMembershipField = .init(parsing: &input)
            {
                self = .topicMembership(field)
            }
            else if let field:ParagraphField = .init(parsing: &input)
            {
                self = .paragraph(field)
            }
            else if let _:Endline = .init(parsing: &input)
            {
                self = .separator 
            }
            else 
            {
                throw input.expected(Self.self, from: start)
            }
        }
    }
    struct DocumentationComment:Parsable 
    {
        let header:HeaderField 
        let fields:[AuxillaryField]
        init(parsing input:inout Input) throws 
        {
            self.header = try .init(parsing: &input)
            self.fields =     .init(parsing: &input)
        }
    }
}

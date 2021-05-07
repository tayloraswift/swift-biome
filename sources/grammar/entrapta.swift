extension Grammar
{
    // Endline ::= ' ' * '\n'
    struct Endline:Parseable 
    {
        init(parsing input:inout Input) throws
        {
            let _:[Token.Space] =     .init(parsing: &input),
                _:Token.Newline = try .init(parsing: &input)
        }
    }
    // EncapsulatedOperator ::= '(' <Swift Operator Head> <Swift Operator Character> * ')'
    struct EncapsulatedOperator:Parseable, CustomStringConvertible
    {
        let string:String 
        
        init(parsing input:inout Input) throws 
        {
            let _:Token.Parenthesis.Left        = try .init(parsing: &input),
                head:Token.Operator.Head        = try .init(parsing: &input),
                body:[Token.Operator.Character] =     .init(parsing: &input), 
                _:Token.Parenthesis.Right       = try .init(parsing: &input)
            self.string = "\(head.character)\(String.init(body.map(\.character)))"
        }
        
        var description:String 
        {
            self.string
        }
    }
    
    //  ModuleField         ::= <ModuleField.Keyword> <Whitespace> <Identifier> <Endline>
    //  ModuleField.Keyword ::= 'module'
    //                        | 'plugin'
    struct ModuleField:Parseable 
    {
        enum Keyword 
        {
            struct Module:Parseable.Terminal 
            {
                static 
                let token:String = "module"
            }
            struct Plugin:Parseable.Terminal 
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
    
    // FunctionField            ::= <FunctionField.Keyword> <Whitespace> <Identifiers> <TypeParameters> ? '?' ? '(' ( <FunctionField.Label> ':' ) * ')' <Endline>
    //                            | 'case' <Whitespace> <Identifiers> <Endline>
    // FunctionField.Keyword    ::= 'init'
    //                            | 'func'
    //                            | 'mutating' <Whitespace> 'func'
    //                            | 'static' <Whitespace> 'func'
    //                            | 'case' 
    //                            | 'indirect' <Whitespace> 'case' 
    // FunctionField.Label      ::= <Identifier> 
    //                            | <Identifier> ? '...'
    // Identifiers              ::= <Identifier> ( '.' <Identifier> ) * ( '.' <EncapsulatedOperator> ) ?
    // TypeParameters           ::= '<' <Whitespace> ? <Identifier> <Whitespace> ? ( ',' <Whitespace> ? <Identifier> <Whitespace> ? ) * '>'
    struct FunctionField:Parseable, CustomStringConvertible
    {
        enum Keyword:Parseable 
        {
            case `init` 
            case `func` 
            case mutatingFunc
            case staticFunc
            case `case`
            case indirectCase
            
            init(parsing input:inout Input) throws 
            {
                let start:String.Index      = input.index 
                if      let _:Token.Init    = .init(parsing: &input)
                {
                    self = .`init`
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
                else if let _:List<Token.Static, List<Whitespace, Token.Func>> = 
                    .init(parsing: &input)
                {
                    self = .staticFunc
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
        
        struct Label:Parseable, CustomStringConvertible
        {
            let string:String, 
                variadic:Bool 
            
            init(parsing input:inout Input) throws
            {
                let start:String.Index      = input.index 
                if      let variadic:List<Identifier?, Token.Ellipsis> = 
                    .init(parsing: &input)
                {
                    self.string     = variadic.head?.string ?? "_" 
                    self.variadic   = true
                }
                else if let singular:Identifier = 
                    .init(parsing: &input)
                {
                    self.string     = singular.string 
                    self.variadic   = false
                }
                else 
                {
                    throw input.expected(Self.self, from: start)
                }
            }
            
            var description:String 
            {
                "\(self.variadic && self.string == "_" ? "" : self.string)\(self.variadic ? "..." : ""):"
            }
        }
        
        private 
        struct Normal:Parseable
        {
            let keyword:Keyword
            let identifiers:[String]
            let generics:[String] 
            let failable:Bool
            let labels:[(name:String, variadic:Bool)]
            
            init(parsing input:inout Input) throws
            {
                self.keyword                            = try .init(parsing: &input) 
                let _:Whitespace                        = try .init(parsing: &input),
                    identifiers:Identifiers             = try .init(parsing: &input),
                    generics:TypeParameters?            =     .init(parsing: &input),
                    failable:Token.Question?            =     .init(parsing: &input),
                    _:Token.Parenthesis.Left            = try .init(parsing: &input),
                    labels:[List<Label, Token.Colon>]   = .init(parsing: &input),
                    _:Token.Parenthesis.Right           = try .init(parsing: &input),
                    _:Endline                           = try .init(parsing: &input)
                self.identifiers    = identifiers.identifiers
                self.generics       = generics?.identifiers ?? [] 
                self.failable       = failable != nil 
                self.labels         = labels.map{ ($0.head.string, $0.head.variadic) }
            }
        }
        private 
        struct UninhabitedCase:Parseable
        {
            let identifiers:[String]
            
            init(parsing input:inout Input) throws
            {
                let _:Token.Case            = try .init(parsing: &input), 
                    _:Whitespace            = try .init(parsing: &input),
                    identifiers:Identifiers = try .init(parsing: &input),
                    _:Endline               = try .init(parsing: &input)
                self.identifiers = identifiers.identifiers
            }
        }
        
        let keyword:Keyword
        let identifiers:[String]
        let generics:[String] 
        let failable:Bool
        let labels:[(name:String, variadic:Bool)]
            
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
            }
            else if let uninhabited:UninhabitedCase = .init(parsing: &input) 
            {
                self.keyword        = .case
                self.identifiers    = uninhabited.identifiers 
                self.generics       = [] 
                self.failable       = false 
                self.labels         = []
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
                labels      : \(self.labels)
            }
            """
        }
    }

    struct TypeParameters:Parseable, CustomStringConvertible
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
    
    // SubscriptField      ::= 'subscript' <Whitespace> <Identifiers> '[' ( <Identifier> ':' ) * ']' <Whitespace> ? <MemberMutability> <Endline> 
    struct SubscriptField:Parseable, CustomStringConvertible
    {
        let identifiers:[String],
            labels:[String], 
            mutability:MemberMutability
            
        init(parsing input:inout Input) throws
        {
            let _:Token.Subscript                       = try .init(parsing: &input), 
                _:Whitespace                            = try .init(parsing: &input),
                identifiers:Identifiers                 = try .init(parsing: &input),
                _:Token.Bracket.Left                    = try .init(parsing: &input),
                labels:[List<Identifier, Token.Colon>]  =     .init(parsing: &input),
                _:Token.Bracket.Right                   = try .init(parsing: &input),
                _:Whitespace?                           =     .init(parsing: &input),
                mutability:MemberMutability             = try .init(parsing: &input),
                _:Endline                               = try .init(parsing: &input)
            self.identifiers    = identifiers.identifiers 
            self.labels         = labels.map(\.head.string) 
            self.mutability     = mutability
        }
        
        var description:String 
        {
            """
            SubscriptField 
            {
                identifiers     : \(self.identifiers)
                labels          : \(self.labels)
            }
            """
        }
    }
    
    // MemberField         ::= <MemberField.Keyword> <Whitespace> <Identifiers> ( <Whitespace> ? ':' <Whitespace> ? <Type> ) ? ( <Whitespace> ? <MemberMutability> ) ? <Endline> 
    // MemberField.Keyword ::= 'let'
    //                       | 'var'
    //                       | 'static' <Whitespace> 'let'
    //                       | 'static' <Whitespace> 'var'
    //                       | 'associatedtype'
    // MemberMutability    ::= '{' <Whitespace> ? 'get' ( ( <Whitespace> 'nonmutating' ) ? <Whitespace> 'set' ) ? <Whitespace> ? '}'
    struct MemberField:Parseable, CustomStringConvertible
    {
        enum Keyword:Parseable 
        {
            case `let` 
            case `var` 
            case staticLet 
            case staticVar
            case `associatedtype`
            
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
                else if let _:Token.Associatedtype = .init(parsing: &input)
                {
                    self = .associatedtype
                }
                else 
                {
                    throw input.expected(Self.self, from: start)
                }
            }
        }
        
        let keyword:Keyword
        let identifiers:[String]
        let type:SwiftType?
        let mutability:MemberMutability?
            
        init(parsing input:inout Input) throws
        {
            self.keyword                = try .init(parsing: &input) 
            let _:Whitespace            = try .init(parsing: &input),
                identifiers:Identifiers = try .init(parsing: &input),
                type:List<Whitespace?, List<Token.Colon, List<Whitespace?, SwiftType>>>? = 
                                              .init(parsing: &input),
                mutability:List<Whitespace?, MemberMutability>? = 
                                              .init(parsing: &input),
                _:Grammar.Endline       = try .init(parsing: &input)
            self.identifiers    = identifiers.identifiers
            self.type           = type?.body.body.body
            self.mutability     = mutability?.body
        }
        
        var description:String 
        {
            """
            MemberField 
            {
                keyword     : \(self.keyword)
                identifiers : \(self.identifiers)
                type        : \(self.type.map(String.init(describing:)) ?? "")
                mutability  : \(self.mutability.map(String.init(describing:)) ?? "")
            }
            """
        }
    }

    enum MemberMutability:Parseable 
    {
        case get 
        case getset
        case nonmutatingset
            
        init(parsing input:inout Input) throws
        {
            let _:Token.Brace.Left  = try .init(parsing: &input), 
                _:Whitespace?       =     .init(parsing: &input),
                _:Token.Get         = try .init(parsing: &input),
                mutability:List<List<Whitespace, Token.Nonmutating>?, List<Whitespace, Token.Set>>? =
                                          .init(parsing: &input),
                _:Whitespace?       =     .init(parsing: &input),
                _:Token.Brace.Right = try .init(parsing: &input)
            if let set:List<List<Whitespace, Token.Nonmutating>?, List<Whitespace, Token.Set>> = 
                mutability 
            {
                if let _:List<Whitespace, Token.Nonmutating> = set.head 
                {
                    self = .nonmutatingset
                }
                else 
                {
                    self = .getset 
                }
            }
            else 
            {
                self = .get 
            }
        }
    }
    
    // TypeField           ::= <TypeField.Keyword> <Whitespace> <Identifiers> <TypeParameters> ? <Endline>
    // TypeField.Keyword   ::= 'protocol'
    //                       | 'class'
    //                       | 'struct'
    //                       | 'enum'
    struct TypeField:Parseable, CustomStringConvertible
    {
        enum Keyword:Parseable 
        {
            case `protocol` 
            case `class` 
            case `struct` 
            case `enum`
            
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
    
    // TypealiasField      ::= 'typealias' <Whitespace> <Identifiers> <Whitespace> ? '=' <Whitespace> ? <Type> <Endline>
    struct TypealiasField:Parseable, CustomStringConvertible
    {
        let identifiers:[String]
        let target:SwiftType
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Typealias       = try .init(parsing: &input), 
                _:Whitespace            = try .init(parsing: &input), 
                identifiers:Identifiers = try .init(parsing: &input), 
                _:Whitespace?           =     .init(parsing: &input), 
                _:Token.Equals          = try .init(parsing: &input), 
                _:Whitespace?           =     .init(parsing: &input), 
                target:SwiftType        = try .init(parsing: &input), 
                _:Endline               = try .init(parsing: &input)
            self.identifiers    = identifiers.identifiers 
            self.target         = target
        }
        
        var description:String 
        {
            """
            TypealiasField 
            {
                identifiers : \(self.identifiers)
                target      : \(self.target)
            }
            """
        }
    }
    
    // ConformanceField    ::= ':' <Whitespace> ? <ProtocolCompositionType> ( <Whitespace> <WhereClauses> ) ? <Endline>
    struct ConformanceField:Parseable, CustomStringConvertible
    {
        let conformances:[[String]]
        let conditions:[WhereClause]
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Colon                               = try .init(parsing: &input), 
                _:Whitespace?                               =     .init(parsing: &input), 
                conformances:ProtocolCompositionType        = try .init(parsing: &input), 
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
    
    //  ImplementationField ::= '?:' <Whitespace> ? <Identifiers> ( <Whitespace> <WhereClauses> ) ? <Endline>
    struct ImplementationField:Parseable 
    {
        let conformance:[String]
        let conditions:[WhereClause]
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Question                            = try .init(parsing: &input),
                _:Token.Colon                               = try .init(parsing: &input), 
                _:Whitespace?                               =     .init(parsing: &input), 
                conformance:Identifiers                     = try .init(parsing: &input), 
                conditions:List<Whitespace, WhereClauses>?  =     .init(parsing: &input), 
                _:Endline                                   = try .init(parsing: &input)
            self.conformance    = conformance.identifiers
            self.conditions     = conditions?.body.clauses ?? []
        }
    }
    
    //  ConstraintsField    ::= <WhereClauses> <Endline>
    //  WhereClauses        ::= 'where' <Whitespace> <WhereClause> ( <Whitespace> ? ',' <Whitespace> ? <WhereClause> ) * 
    //  WhereClause         ::= <Identifiers> <Whitespace> ? <WherePredicate>
    //  WherePredicate      ::= ':' <Whitespace> ? <ProtocolCompositionType> 
    //                        | '==' <Whitespace> ? <Type>
    struct ConstraintsField:Parseable, CustomStringConvertible
    {
        let clauses:[WhereClause]
        
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
    struct WhereClauses:Parseable 
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
    struct WhereClause:Parseable, CustomStringConvertible
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
    enum WherePredicate:Parseable
    {
        case conforms([[String]]) 
        case equals(SwiftType) 
        
        init(parsing input:inout Input) throws
        {
            let start:String.Index = input.index 
            if      let _:List<Token.Colon, Whitespace?> = 
                .init(parsing: &input), 
                    let protocols:ProtocolCompositionType = 
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
    
    //  AttributeField      ::= '@' <Whitespace> ? <DeclarationAttribute> <Endline>
    //  DeclarationAttribute::= 'frozen'
    //                        | 'inlinable'
    //                        | 'propertyWrapper'
    //                        | 'specialized' <Whitespace> <WhereClauses>
    //                        | ':'  <Whitespace> ? <Type>
    enum AttributeField:Parseable
    {
        private 
        struct Frozen:Parseable.Terminal 
        {
            static 
            let token:String = "frozen"
        }
        private 
        struct Inlinable:Parseable.Terminal 
        {
            static 
            let token:String = "inlinable"
        }
        private 
        struct PropertyWrapper:Parseable.Terminal 
        {
            static 
            let token:String = "propertyWrapper"
        }
        private 
        struct Specialized:Parseable.Terminal 
        {
            static 
            let token:String = "specialized"
        }
        
        case frozen 
        case inlinable 
        case wrapper
        case specialized(WhereClauses)
        case wrapped(SwiftType)
        
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
            else if let _:List<PropertyWrapper, Endline> = 
                .init(parsing: &input)
            {
                self = .wrapper 
            }
            else if let specialized:List<Specialized, List<Whitespace, List<WhereClauses, Endline>>> = 
                .init(parsing: &input)
            {
                self = .specialized(specialized.body.body.head)
            }
            else if let wrapped:List<Token.Colon, List<Whitespace?, List<SwiftType, Endline>>> = 
                .init(parsing: &input)
            {
                self = .wrapped(wrapped.body.body.head) 
            }
            else 
            {
                throw input.expected(Self.self, from: start)
            }
        }
    }
    
    // ParameterField      ::= '-' <Whitespace> ? <ParameterName> <Whitespace> ? ':' <Whitespace> ? <FunctionParameter> <Endline>
    // ParameterName       ::= <Identifier> 
    //                       | '->'
    struct ParameterField:Parseable, CustomStringConvertible
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
    enum ParameterName:Parseable
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
    
    // ThrowsField         ::= 'throws' <Endline>
    //                       | 'rethrows' <Endline>
    enum ThrowsField:Parseable 
    {
        case `throws` 
        case `rethrows`
        
        init(parsing input:inout Input) throws
        {
            let start:String.Index                      = input.index 
            if      let _:List<Token.Throws, Endline>   = .init(parsing: &input)
            {
                self = .throws
            }
            else if let _:List<Token.Rethrows, Endline> = .init(parsing: &input)
            {
                self = .rethrows
            }
            else 
            {
                throw input.expected(Self.self, from: start)
            }
        }
    }
    
    // RequirementField    ::= 'required' <Endline>
    //                       | 'defaulted' ( <Whitespace> <WhereClauses> ) ? <Endline>
    enum RequirementField:Parseable 
    {
        private 
        struct Required:Parseable.Terminal 
        {
            static 
            let token:String = "required"
        }
        private 
        struct Defaulted:Parseable.Terminal 
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
            }
            else if let _:Defaulted = .init(parsing: &input)
            {
                let conditions:List<Whitespace, WhereClauses>? = 
                    .init(parsing: &input) 
                if let _:Endline = .init(parsing: &input) 
                {
                    self = .defaulted(conditions?.body.clauses ?? [])
                }
            }
            throw input.expected(Self.self, from: start)
        }
    }
    
    // TopicKey            ::= [a-zA-Z0-9\-] *
    // TopicField          ::= '#' <Whitespace>? '[' <BalancedContent> * ']' <Whitespace>? '(' <Whitespace> ? <TopicKey> ( <Whitespace> ? ',' <Whitespace> ? <TopicKey> ) * <Whitespace> ? ')' <Endline>
    // TopicElementField   ::= '##' <Whitespace>? '(' <Whitespace> ? ( <ASCIIDigit> * <Whitespace> ? ':' <Whitespace> ? ) ? <TopicKey> <Whitespace> ? ')' <Endline>
    struct TopicField:Parseable 
    {
        let display:String, 
            keys:[String] 
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Hashtag                 = try .init(parsing: &input), 
                _:Whitespace?                   =     .init(parsing: &input), 
                _:Token.Bracket.Left            = try .init(parsing: &input), 
                display:[Token.BalancedContent] = .init(parsing: &input), 
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
            self.display = .init(display.map(\.character))
        }
    }
    struct TopicElementField:Parseable
    {
        let key:String?
        let rank:Int
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Hashtag             = try .init(parsing: &input), 
                _:Token.Hashtag             = try .init(parsing: &input), 
                _:Whitespace?               =     .init(parsing: &input), 
                _:Token.Parenthesis.Left    = try .init(parsing: &input), 
                _:Whitespace?               =     .init(parsing: &input), 
                rank:List<[Token.ASCIIDigit], List<Whitespace?, List<Token.Colon, Whitespace?>>>? = 
                                                  .init(parsing: &input),
                key:[Token.Alphanumeric]    =     .init(parsing: &input), 
                _:Whitespace?               =     .init(parsing: &input), 
                _:Token.Parenthesis.Right   = try .init(parsing: &input), 
                _:Endline                   = try .init(parsing: &input)
            self.rank   = Int.init(String.init(rank?.head.map(\.character) ?? [])) ?? Int.max
            self.key    = key.isEmpty ? nil : .init(key.map(\.character))
        }
    }
    
    // ParagraphField      ::= <ParagraphLine> <ParagraphLine> *
    // ParagraphLine       ::= '    ' ' ' * [^\s] . * '\n'
    struct ParagraphField:Parseable, CustomStringConvertible
    {
        let elements:[Markdown.Element]
        
        init(parsing input:inout Input) throws
        {
            let head:ParagraphLine   = try .init(parsing: &input), 
                body:[ParagraphLine] =     .init(parsing: &input)
            
            let content:String = ([head] + body).map
            {
                (line:ParagraphLine) -> Substring in 
                
                var substring:Substring = line.string[...] 
                while substring.last?.isWhitespace == true 
                {
                    substring.removeLast()
                }
                return substring
            }.joined(separator: " ")
            
            self.elements = .init(parsing: content)
        }
        
        var description:String 
        {
            "\(self.elements)"
        }
    }
    struct ParagraphLine:Parseable 
    {
        let string:String
        
        init(parsing input:inout Input) throws
        {
            let _:Token.Space           = try .init(parsing: &input), 
                _:Token.Space           = try .init(parsing: &input), 
                _:Token.Space           = try .init(parsing: &input), 
                _:Token.Space           = try .init(parsing: &input), 
                _:Whitespace?           =     .init(parsing: &input), 
                head:Token.Darkspace    = try .init(parsing: &input), 
                body:[Token.Wildcard]   =     .init(parsing: &input), 
                _:Token.Newline         = try .init(parsing: &input)
            self.string = .init([head.character] + body.map(\.character))
        }
    }
    
    // Field               ::= <ModuleField>
    //                       | <FunctionField>
    //                       | <SubscriptField>
    //                       | <MemberField>
    //                       | <TypeField>
    //                       | <TypealiasField>
    //                       | <AnnotationField>
    //                       | <AttributeField>
    //                       | <ConstraintsField>
    //                       | <ThrowsField>
    //                       | <RequirementField>
    //                       | <ParameterField>
    //                       | <TopicField>
    //                       | <TopicElementField>
    //                       | <ParagraphField>
    //                       | <Separator>
    // Separator           ::= <Endline>
    enum Field:Parseable 
    {
        case module(ModuleField) 
        
        case `subscript`(SubscriptField) 
        case function(FunctionField) 
        case member(MemberField) 
        case type(TypeField) 
        case `typealias`(TypealiasField) 
        
        case implementation(ImplementationField) 
        case conformance(ConformanceField) 
        case constraints(ConstraintsField) 
        case attribute(AttributeField) 
        case `throws`(ThrowsField) 
        case requirement(RequirementField) 
        case parameter(ParameterField) 
        
        case topic(TopicField)
        case topicElement(TopicElementField)
        
        case paragraph(ParagraphField) 
        case separator
        
        init(parsing input:inout Input) throws
        {
            let start:String.Index = input.index 
            if      let field:ModuleField = .init(parsing: &input)
            {
                self = .module(field)
            }
            else if let field:FunctionField = .init(parsing: &input)
            {
                self = .function(field)
            }
            else if let field:SubscriptField = .init(parsing: &input)
            {
                self = .subscript(field)
            }
            else if let field:MemberField = .init(parsing: &input)
            {
                self = .member(field)
            }
            else if let field:TypeField = .init(parsing: &input)
            {
                self = .type(field)
            }
            else if let field:TypealiasField = .init(parsing: &input)
            {
                self = .typealias(field)
            }
            else if let field:ImplementationField = .init(parsing: &input)
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
            else if let field:ThrowsField = .init(parsing: &input)
            {
                self = .throws(field)
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
            else if let field:TopicElementField = .init(parsing: &input)
            {
                self = .topicElement(field)
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
}

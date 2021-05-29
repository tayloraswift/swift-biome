extension Page 
{
    struct Fields
    {
        struct Callable 
        {
            let domain:[(type:Grammar.FunctionParameter, paragraphs:[[Markdown.Element]], name:String)]
            let range:(type:Grammar.SwiftType, paragraphs:[[Markdown.Element]])?
            
            var isEmpty:Bool 
            {
                self.domain.isEmpty && self.range == nil 
            }
        }
        
        enum Relationships 
        {
            case required
            case defaulted 
            case defaultedConditionally([[Grammar.WhereClause]]) 
            case implements([Grammar.ImplementationField])
        }
        
        let attributes:[Grammar.AttributeField], 
            conformances:[Grammar.ConformanceField], 
            constraints:Grammar.ConstraintsField?, 
            dispatch:Grammar.DispatchField? 
        
        let callable:Callable
        private(set)
        var relationships:Relationships?
        
        let paragraphs:[Grammar.ParagraphField],
            topics:[Grammar.TopicField], 
            memberships:[Grammar.TopicMembershipField]
            
        var blurb:[Markdown.Element]?
        {
            self.paragraphs.first?.elements
        }
        var discussion:[[Markdown.Element]]
        {
            self.paragraphs.dropFirst().map(\.elements)
        }
    }
}
extension Page.Fields 
{
    init() 
    {
        self.attributes     = []
        self.conformances   = []
        self.constraints    = nil 
        self.dispatch       = nil 
        self.callable       = .init(domain: [], range: nil)
        self.relationships  = nil 
        self.paragraphs     = []
        self.topics         = []
        self.memberships    = []
    }
    
    init<S>(_ fields:S) throws where S:Sequence, S.Element == Grammar.Field 
    {
        typealias ParameterDescription = 
        (
            parameter:Grammar.ParameterField, 
            paragraphs:[Grammar.ParagraphField]
        )
        
        var attributes:[Grammar.AttributeField]             = [], 
            conformances:[Grammar.ConformanceField]         = [], 
            constraints:Grammar.ConstraintsField?           = nil, 
            dispatch:Grammar.DispatchField?                 = nil
         
        var parameters:[ParameterDescription]               = [] 
        
        var implementations:[Grammar.ImplementationField]   = [],
            requirements:[Grammar.RequirementField]         = [] 
            
        var paragraphs:[Grammar.ParagraphField]             = [],
            topics:[Grammar.TopicField]                     = [], 
            memberships:[Grammar.TopicMembershipField]      = []
            
        for field:Grammar.Field in fields
        {
            switch field 
            {
            case .attribute     (let field):
                attributes.append(field)
            case .conformance   (let field):
                conformances.append(field)
            case .implementation(let field):
                implementations.append(field)
            case .requirement   (let field):
                requirements.append(field)
            
            case .constraints   (let field):
                guard constraints == nil 
                else 
                {
                    throw Entrapta.Error.init("only one constraints field per doccomnent allowed")
                }
                constraints = field
            case .paragraph     (let field):
                if parameters.isEmpty 
                {
                    paragraphs.append(field)
                }
                else 
                {
                    parameters[parameters.endIndex - 1].paragraphs.append(field)
                }
            case .topic             (let field):
                topics.append(field)
            case .topicMembership   (let field):
                memberships.append(field)
            
            case .parameter     (let field):
                parameters.append((field, []))
            
            case .dispatch      (let field):
                guard dispatch == nil 
                else 
                {
                    throw Entrapta.Error.init("only one dispatch field per doccomnent allowed")
                }
                dispatch = field 
            
            case .subscript, .function, .property, .associatedtype, .typealias, .type, .framework, .dependency, .lexeme:
                throw Entrapta.Error.init("only one header field per doccomnent allowed")
                
            case .separator:
                break
            }
        }
        
        self.attributes         = attributes
        self.conformances       = conformances
        self.constraints        = constraints
        self.dispatch           = dispatch
        
        // validate relationships 
        switch (implementations.isEmpty, requirements.isEmpty) 
        {
        case (true, true):
            self.relationships      = nil 
        case (false, true):
            self.relationships      = .implements(implementations)
        case (true, false):
            if      case .required?                     = requirements.first, 
                    requirements.count == 1 
            {
                self.relationships  = .required 
            }
            else if case .defaulted(let conditions)?    = requirements.first, 
                    requirements.count == 1, 
                    conditions.isEmpty
            {
                self.relationships  = .defaulted
            }
            else 
            {
                let conditions:[[Grammar.WhereClause]] = requirements.compactMap 
                {
                    guard case .defaulted(let conditions) = $0, !conditions.isEmpty
                    else 
                    {
                        return nil 
                    }
                    return conditions 
                }
                guard conditions.count == requirements.count 
                else 
                {
                    throw Entrapta.Error.init("if conditional `defaulted` field is present, all requirements fields must be this type")
                }
                self.relationships  = .defaultedConditionally(conditions)
            }
        case (false, false):
            throw Entrapta.Error.init("cannot have both implementations fields and requirements fields in the same doccomment")
        }
        
        // validate function fields 
        let range:(type:Grammar.SwiftType, paragraphs:[[Markdown.Element]])?
        if  let last:ParameterDescription   = parameters.last, 
            case .return                    = last.parameter.name
        {
            range = (last.parameter.parameter.type, last.paragraphs.map(\.elements))
            parameters.removeLast()
        }
        else 
        {
            range = nil 
        }
        let domain:[(type:Grammar.FunctionParameter, paragraphs:[[Markdown.Element]], name:String)] = 
            try parameters.map 
        {
            guard case .parameter(let name) = $0.parameter.name 
            else 
            {
                throw Entrapta.Error.init("return value must be the last parameter field")
            }
            return ($0.parameter.parameter, $0.paragraphs.map(\.elements), name)
        }
        
        self.callable = .init(domain: domain, range: range)
        
        self.paragraphs         = paragraphs
        self.topics             = topics 
        self.memberships        = memberships
    }
    
    // used for associated types, which infer their relationships automatically 
    mutating 
    func update(relationships:Relationships)
    {
        self.relationships = relationships
    }
}

extension Page 
{
    convenience 
    init(_ header:Grammar.FrameworkField, fields:Fields, order:Int) throws 
    {
        guard fields.relationships == nil 
        else 
        {
            throw Entrapta.Error.init("framework doccomment cannot have relationships fields")
        }
        guard fields.conformances.isEmpty 
        else 
        {
            throw Entrapta.Error.init("framework doccomment cannot have conformance fields")
        }
        guard fields.constraints == nil 
        else 
        {
            throw Entrapta.Error.init("framework doccomment cannot have a constraints field")
        }
        guard fields.dispatch == nil 
        else 
        {
            throw Entrapta.Error.init("framework doccomment cannot have a dispatch field")
        }
        guard fields.callable.isEmpty
        else 
        {
            throw Entrapta.Error.init("framework doccomment cannot have callable fields")
        }
        
        let kind:Kind 
        switch header.keyword 
        {
        case .module:   kind = .module(.local) 
        case .plugin:   kind = .plugin
        }
        try self.init(path: [], 
            name:           header.identifier, 
            kind:           kind, 
            signature:      .empty, 
            declaration:    .empty, 
            fields:         fields, 
            order:          order)
    }
    convenience 
    init(_ header:Grammar.DependencyField, fields:Fields, order:Int) throws
    {
        guard fields.relationships == nil 
        else 
        {
            throw Entrapta.Error.init("dependency doccomment cannot have relationships fields")
        }
        guard fields.attributes.isEmpty 
        else 
        {
            throw Entrapta.Error.init("dependency doccomment cannot have attribute fields")
        }
        guard fields.conformances.isEmpty 
        else 
        {
            throw Entrapta.Error.init("dependency doccomment cannot have conformance fields")
        }
        guard fields.constraints == nil 
        else 
        {
            throw Entrapta.Error.init("dependency doccomment cannot have a constraints field")
        }
        guard fields.dispatch == nil 
        else 
        {
            throw Entrapta.Error.init("dependency doccomment cannot have a dispatch field")
        }
        guard fields.callable.isEmpty
        else 
        {
            throw Entrapta.Error.init("dependency doccomment cannot have callable fields")
        }
        
        let name:String, 
            kind:Kind,
            path:[String], 
            signature:Signature, 
            declaration:Declaration
        switch header 
        {
        case .module(identifier: let identifier):
            name        = identifier 
            kind        = .module(.imported) 
            signature   = .init 
            {
                Signature.text("import")
                Signature.whitespace 
                Signature.text(highlighting: identifier)
            }
            declaration = .init 
            {
                Declaration.keyword("import")
                Declaration.whitespace
                Declaration.identifier(identifier)
            }
            
            path = [identifier]
        case .type(keyword: let keyword, identifiers: let identifiers):
            name        = identifiers[identifiers.endIndex - 1]
            switch keyword 
            {
            case .protocol:     kind = .protocol    (module: .imported)
            case .enum:         kind = .enum        (module: .imported, generic: false) 
            case .struct:       kind = .struct      (module: .imported, generic: false) 
            case .class:        kind = .class       (module: .imported, generic: false) 
            case .typealias:    kind = .typealias   (module: .imported, generic: false)
            }
            signature   = .init 
            {
                Signature.text("\(keyword)")
                Signature.whitespace 
                Signature.init(joining: identifiers, Signature.text(highlighting:))
                {
                    Signature.punctuation(".")
                }
            }
            declaration = .init 
            {
                Declaration.keyword("import")
                Declaration.whitespace
                Declaration.keyword("\(keyword)")
                Declaration.whitespace(breakable: false)
                Declaration.init(typename: identifiers.dropLast())
                Declaration.punctuation(".")
                Declaration.identifier(name)
            }
            path = identifiers 
        }
        try self.init(path: path, 
            name:           name, 
            kind:           kind, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            order:          order)
    }
    convenience 
    init(_ header:Grammar.LexemeField, fields:Fields, order:Int) throws
    {
        guard fields.relationships == nil 
        else 
        {
            throw Entrapta.Error.init("lexeme doccomment cannot have relationships fields")
        }
        guard fields.attributes.isEmpty 
        else 
        {
            throw Entrapta.Error.init("lexeme doccomment cannot have attribute fields")
        }
        guard fields.conformances.isEmpty 
        else 
        {
            throw Entrapta.Error.init("lexeme doccomment cannot have conformance fields", 
                help: "write the precedence annotaton on the same line as the lexeme declaration.")
        }
        guard fields.constraints == nil 
        else 
        {
            throw Entrapta.Error.init("lexeme doccomment cannot have a constraints field")
        }
        guard fields.dispatch == nil 
        else 
        {
            throw Entrapta.Error.init("lexeme doccomment cannot have a dispatch field")
        }
        guard fields.callable.isEmpty
        else 
        {
            throw Entrapta.Error.init("lexeme doccomment cannot have callable fields")
        }
        
        let precedence:String?
        switch (header.keyword, header.precedence)
        {
        case    (.infix, "BitwiseShiftPrecedence"?),
                (.infix, "MultiplicationPrecedence"?),
                (.infix, "AdditionPrecedence"?),
                (.infix, "RangeFormationPrecedence"?),
                (.infix, "CastingPrecedence"?),
                (.infix, "NilCoalescingPrecedence"?),
                (.infix, "ComparisonPrecedence"?),
                (.infix, "LogicalConjunctionPrecedence"?),
                (.infix, "LogicalDisjunctionPrecedence"?),
                (.infix, "DefaultPrecedence"?),
                (.infix, "TernaryPrecedence"?),
                (.infix, "AssignmentPrecedence"?):
            // okay 
            precedence = header.precedence
        case    (.infix, nil):
            precedence = "DefaultPrecedence"
        case    (.infix, let precedence?):
            throw Entrapta.Error.init("precedence '\(precedence)' is not a valid precedence group")
        case    (.prefix, nil), (.postfix, nil):
            // okay
            precedence = nil
        case    (.prefix, _?), (.postfix, _?):
            throw Entrapta.Error.init(
                "lexeme doccomment can only specify a precedence group if its keyword is `infix`")
        }
        
        let signature:Signature, 
            declaration:Declaration
        signature   = .init 
        {
            Signature.text("\(header.keyword)")
            Signature.whitespace 
            Signature.text("operator")
            Signature.whitespace 
            Signature.text(highlighting: header.lexeme)
        }
        declaration = .init 
        {
            Declaration.keyword("\(header.keyword)")
            Declaration.whitespace
            Declaration.keyword("operator")
            Declaration.whitespace(breakable: false)
            Declaration.identifier(header.lexeme)
            if let precedence:String = precedence 
            {
                Declaration.whitespace
                Declaration.punctuation(":")
                Declaration.identifier(precedence, link: .init(builtin: 
                    ["Swift", "swift_standard_library", "operator_declarations"]))
            }
        }
        try self.init(path: ["\(header.keyword) operator \(header.lexeme)"], 
            name:           header.lexeme, 
            kind:          .lexeme(module: .local), 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            order:          order)
    }
    convenience 
    init(_ header:Grammar.SubscriptField, fields:Fields, order:Int) throws 
    {
        guard fields.conformances.isEmpty 
        else 
        {
            throw Entrapta.Error.init("subscript doccomment cannot have conformance fields")
        }
        guard fields.callable.domain.count == header.labels.count
        else 
        {
            throw Entrapta.Error.init(
                "subscript has \(header.labels.count) labels, but \(fields.callable.domain.count) parameters")
        }
        guard fields.callable.range != nil
        else 
        {
            throw Entrapta.Error.init("subscript doccomment must have a return value field")
        }
        
        let name:String                             = "[\(header.labels.map{ "\($0):" }.joined())]" 
        let labels:[(name:String, variadic:Bool)]   = header.labels.map{ ($0, false) }
        let signature:Signature     = .init 
        {
            Signature.text(highlighting: "subscript")
            Signature.init(generics: header.generics)
            Signature.init(callable: fields.callable, labels: labels, throws: nil, 
                delimiters: ("[", "]"))
        }
        let declaration:Declaration = .init 
        {
            Declaration.init(attributes: fields.attributes)
            if let dispatch:Grammar.DispatchField = fields.dispatch 
            {
                Declaration.init(modifiers: dispatch)
                Declaration.whitespace 
            }
            Declaration.keyword("subscript")
            Declaration.init(generics: header.generics)
            Declaration.init(callable: fields.callable, labels: labels, throws: nil)
            {
                switch ($0, $1) 
                {
                case ("_",             "_"):    return [         "_"]
                case ("_",       let inner):    return [       inner]
                case (let outer, let inner):    return [outer, inner]
                }
            }
            if let clauses:[Grammar.WhereClause] = fields.constraints?.clauses 
            {
                Declaration.whitespace
                Declaration.init(constraints: clauses) 
            }
            if let accessors:Grammar.Accessors = header.accessors 
            {
                Declaration.whitespace 
                Declaration.init(accessors: accessors)
            }
        }
        
        try self.init(path: header.identifiers + [name], 
            name:           name, 
            kind:          .subscript(generic: !header.generics.isEmpty), 
            signature:      signature, 
            declaration:    declaration, 
            generics:       header.generics,
            fields:         fields, 
            order:          order)
    }
    convenience 
    init(_ header:Grammar.FunctionField, fields:Fields, order:Int) throws 
    {
        guard fields.conformances.isEmpty 
        else 
        {
            throw Entrapta.Error.init("function/case doccomment cannot have conformance fields")
        }
        switch (header.keyword, fields.dispatch)
        {
        case    (.case, _?), (.indirectCase, _?), 
                (.prefixFunc, _?), (.postfixFunc, _?), 
                (.staticFunc, _?), (.staticPrefixFunc, _?), (.staticPostfixFunc, _?):
            throw Entrapta.Error.init(
                """
                function/case doccomment cannot have a dispatch field if its \
                keyword is `case`, `indirect case`, `static func`, \
                `prefix func`, `postfix func`, `static prefix func`, or `static postfix func`
                """)
        default:
            break 
        }
        
        switch (header.keyword, header.identifiers.prefix)
        {
        case    (.func, []), (.prefixFunc, []), (.postfixFunc, []): // okay 
            break 
        case    (_,     []):
            throw Entrapta.Error.init(
                "function/case doccomment can only be declared at the toplevel if its keyword is 'func'")
        default:
            break 
        }
        switch (header.keyword, header.identifiers.tail)
        {
        case    (.`init`,               .alphanumeric("init")): // okay 
            break
        case    (.`init`,               _): 
            throw Entrapta.Error.init("initializer must have basename 'init'")
        case    (.func,                 .alphanumeric("callAsFunction")),
                (.mutatingFunc,         .alphanumeric("callAsFunction")): // okay 
            break
        case    (_,                     .alphanumeric("callAsFunction")):
            throw Entrapta.Error.init(
                "function/case doccomment can only have basename 'callAsFunction' if its keyword is `func` or `mutating func`")
        case    (.func,                 .operator(_)), 
                (.staticFunc,           .operator(_)),
                (.prefixFunc,           .operator(_)),
                (.postfixFunc,          .operator(_)),
                (.staticPrefixFunc,     .operator(_)),
                (.staticPostfixFunc,    .operator(_)): // okay 
            break 
        case    (.prefixFunc,           .alphanumeric(_)),
                (.postfixFunc,          .alphanumeric(_)),
                (.staticPrefixFunc,     .alphanumeric(_)),
                (.staticPostfixFunc,    .alphanumeric(_)): 
            throw Entrapta.Error.init(
                """
                function/case doccomment must have an operator basename if its \
                keyword is `prefix func`, `postfix func`, `static prefix func`, or `static postfix func`
                """)  
        case    (_,                     .operator(_)):
            throw Entrapta.Error.init(
                """
                function/case doccomment can only have an operator basename if its \
                keyword is `func`, `prefix func`, `postfix func`, \
                `static func`, `static prefix func`, or `static postfix func`
                """) 
        case    (_,                     .alphanumeric(_)): // okay
            break 
        }
        
        switch (header.keyword, header.labels?.count, fields.callable.domain.count)
        {
        case (.case, nil, 0), (.indirectCase, nil, 0):  break // okay
        case (.case,  _?, 0), (.indirectCase,  _?, 0): 
            throw Entrapta.Error.init(
                "uninhabited enumeration case must be written without parentheses")
        case (_, fields.callable.domain.count?, _):     break // okay 
        case (_, let labels?, let parameters):
            throw Entrapta.Error.init(
                "function/case has \(labels) labels, but \(parameters) parameters")
        case (_, nil, _):
            throw Entrapta.Error.init(
                "function/case doccomment can only omit parentheses if its keyword is `case` or `indirect case`")
        }
        
        switch 
        (
            header.keyword, 
            fields.callable.range, 
            header.throws, 
            fields.callable.domain.map(\.name) == header.labels?.map(\.name) ?? [],
            header.labels?.allSatisfy{ !$0.variadic } ?? true
        )
        {
        case (.case, _?, _, _, _), (.indirectCase, _?, _, _, _):
            throw Entrapta.Error.init(
                "function/case doccomment cannot have a return value field if its keyword is `case` or `indirect case`")
        case (.case, _, _?, _, _), (.indirectCase, _, _?, _, _):
            throw Entrapta.Error.init(
                "enumeration case cannot be marked `throws` or `rethrows`")
        case (.case, _, _, false, _), (.indirectCase, _, _, false, _):
            throw Entrapta.Error.init(
                "enumeration case cannot have different argument labels and parameter names")
        case (.case, _, _, _, false), (.indirectCase, _, _, _, false):
            throw Entrapta.Error.init(
                "enumeration case cannot have variadic arguments")
        default: 
            break // okay
        }
        
        let keywords:[String]
        switch header.keyword 
        {
        case .`init`:           keywords = []
        case .func:             keywords = ["func"]
        case .mutatingFunc:     keywords = ["mutating", "func"]
        case .prefixFunc:       keywords = ["prefix", "func"]
        case .postfixFunc:      keywords = ["postfix", "func"]
        case .staticFunc:       keywords = ["static", "func"]
        case .staticPrefixFunc: keywords = ["static", "prefix", "func"]
        case .staticPostfixFunc:keywords = ["static", "postfix", "func"]
        case .case:             keywords = ["case"]
        case .indirectCase:     keywords = ["indirect", "case"]
        }
        let kind:Kind 
        switch (header.keyword, header.identifiers.prefix, header.identifiers.tail)
        {
        case    (.`init`,               _, _           ):   
            kind = .initializer     (generic: !header.generics.isEmpty) 
        case    (_,                     _, .operator(_)), 
                (.prefixFunc,           _, _           ),
                (.postfixFunc,          _, _           ),
                (.staticPrefixFunc,     _, _           ),
                (.staticPostfixFunc,    _, _           ): 
            kind = .operator        (generic: !header.generics.isEmpty) 
        case    (.func,                [], _           ):
            kind = .function        (generic: !header.generics.isEmpty) 
        case    (_, _,  .alphanumeric("callAsFunction")):
            kind = .functor         (generic: !header.generics.isEmpty) 
        case    (.func,                 _, _           ):
            kind = .instanceMethod  (generic: !header.generics.isEmpty)
        case    (.mutatingFunc,         _, _           ):
            kind = .instanceMethod  (generic: !header.generics.isEmpty)
        case    (.staticFunc,           _, _           ):
            kind = .staticMethod    (generic: !header.generics.isEmpty)
        
        case    (.case,                 _, _           ),
                (.indirectCase,         _, _           ):
            guard header.generics.isEmpty 
            else 
            {
                throw Entrapta.Error.init("enumeration case cannot have generic parameters")
            }
            kind = .case
        }
        
        let signature:Signature     = .init 
        {
            Signature.init(joining: keywords)
            {
                if case .alphanumeric("callAsFunction") = header.identifiers.tail 
                {
                    Signature.text(highlighting: $0)
                }
                else 
                {
                    Signature.text($0)
                }
            }
            separator: 
            {
                Signature.whitespace
            }
            switch (header.keyword, header.identifiers.tail)
            {
            case (.`init`, _):
                Signature.text(highlighting: "init")
            case (_, .alphanumeric("callAsFunction")):
                let _:Void = ()
            case (_, .alphanumeric(let basename)):
                Signature.whitespace
                Signature.text(highlighting: basename)
            case (_, .operator(let string)):
                Signature.whitespace
                Signature.text(highlighting: string)
                Signature.whitespace
            }
            if header.failable 
            {
                Signature.punctuation("?")
            }
            Signature.init(generics: header.generics)
            // no parentheses if uninhabited enum case 
            if let labels:[(name:String, variadic:Bool)] = header.labels
            {
                Signature.init(callable: fields.callable, labels: labels, 
                    throws: header.throws, delimiters: ("(", ")"))
            }
        }
        let declaration:Declaration = .init 
        {
            Declaration.init(attributes: fields.attributes)
            if let dispatch:Grammar.DispatchField = fields.dispatch 
            {
                Declaration.init(modifiers: dispatch)
                Declaration.whitespace 
            }
            for keyword:String in keywords 
            {
                Declaration.keyword(keyword)
                Declaration.whitespace
            }
            switch (header.keyword, header.identifiers.tail)
            {
            case    (.`init`, _):
                Declaration.keyword("init")
            case    (_, .alphanumeric("callAsFunction")):
                Declaration.keyword("callAsFunction")
            case    (_, .alphanumeric(let basename)):
                Declaration.identifier(basename)
            case    (.prefixFunc,           .operator(let string)), 
                    (.staticPrefixFunc,     .operator(let string)):
                Declaration.identifier(string, link: .unresolved(path: ["prefix operator \(string)"]))
            case    (.postfixFunc,          .operator(let string)), 
                    (.staticPostfixFunc,    .operator(let string)):
                Declaration.identifier(string, link: .unresolved(path: ["postfix operator \(string)"]))
                Declaration.whitespace(breakable: false)
            case    (_,                     .operator(let string)):
                Declaration.identifier(string, link: .unresolved(path: ["infix operator \(string)"]))
                Declaration.whitespace(breakable: false)
            }
            if header.failable 
            {
                Declaration.punctuation("?", link: .optional)
            }
            Declaration.init(generics: header.generics)
            // no parentheses if uninhabited enum case 
            if let labels:[(name:String, variadic:Bool)] = header.labels
            {
                Declaration.init(callable: fields.callable, labels: labels, throws: header.throws)
                {
                    $0 == $1 ? [$0] : [$0, $1] 
                }
            }
            if let clauses:[Grammar.WhereClause] = fields.constraints?.clauses 
            {
                Declaration.whitespace
                Declaration.init(constraints: clauses) 
            }
        }
        
        let suffix:String? = header.labels.map 
        {
            $0.map
            { 
                "\($0.variadic && $0.name == "_" ? "" : $0.name)\($0.variadic ? "..." : ""):" 
            }.joined()
        }
        let name:String 
        switch (header.identifiers.tail, suffix)
        {
        case (.alphanumeric("callAsFunction"), let suffix?):    name =                   "(\(suffix))"
        case (let basename,                    let suffix?):    name = "\(basename.string)(\(suffix))"
        case (let basename,                    nil        ):    name =    basename.string
        }
        
        try self.init(path: header.identifiers.prefix + [name],
            name:           name, 
            kind:           kind, 
            signature:      signature, 
            declaration:    declaration, 
            generics:       header.generics, 
            fields:         fields, 
            order:          order)
    }
    convenience 
    init(_ header:Grammar.PropertyField, fields:Fields, order:Int) throws 
    {
        guard fields.conformances.isEmpty 
        else 
        {
            throw Entrapta.Error.init("property doccomment cannot have conformance fields", 
                help: "write property type annotations on the same line as its name.")
        }
        guard fields.constraints == nil
        else 
        {
            throw Entrapta.Error.init("property doccomment cannot have a constraints field", 
                help: "use relationships fields to specify property availability.")
        }
        guard fields.callable.isEmpty
        else 
        {
            throw Entrapta.Error.init("property doccomment cannot have callable fields")
        }
        switch (header.keyword, fields.dispatch)
        {
        case (.var, _), (_, nil):   break // okay 
        case (_, _?):
            throw Entrapta.Error.init(
                "property doccomment can only have a dispatch field if its keyword is `var`") 
        }
        switch (header.keyword, header.accessors)
        {
        case (.var, _), (.staticVar, _), (_, nil):   break // okay 
        case (_, _?):
            throw Entrapta.Error.init(
                "property doccomment can only have accessors if keyword is `var` or `static var`") 
        }
        
        let name:String = header.identifiers[header.identifiers.endIndex - 1] 
        
        let kind:Kind, 
            keywords:[String]
        switch header.keyword
        {
        case .let:
            kind        = .instanceProperty 
            keywords    = ["let"]
        case .var:
            kind        = .instanceProperty 
            keywords    = ["var"]
        case .staticLet:
            kind        = .staticProperty 
            keywords    = ["static", "let"]
        case .staticVar:
            kind        = .staticProperty 
            keywords    = ["static", "var"]
        }
        
        let signature:Signature     = .init 
        {
            for keyword:String in keywords 
            {
                Signature.text(keyword)
                Signature.whitespace
            }
            Signature.text(highlighting: name)
            Signature.punctuation(":")
            Signature.init(type: header.type)
        }
        let declaration:Declaration = .init 
        {
            Declaration.init(attributes: fields.attributes)
            if let dispatch:Grammar.DispatchField       = fields.dispatch 
            {
                Declaration.init(modifiers: dispatch)
                Declaration.whitespace 
            }
            for keyword:String in keywords 
            {
                Declaration.keyword(keyword)
                Declaration.whitespace
            }
            Declaration.identifier(name)
            Declaration.punctuation(":")
            Declaration.init(type: header.type)
            if let accessors:Grammar.Accessors  = header.accessors
            {
                Declaration.whitespace 
                Declaration.init(accessors: accessors)
            }
        }
        
        try self.init(path: header.identifiers, 
            name:           name, 
            kind:           kind, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            order:          order)
    }
    convenience 
    init(_ header:Grammar.TypealiasField, fields:Fields, order:Int) throws 
    {
        guard fields.callable.isEmpty
        else 
        {
            throw Entrapta.Error.init("typealias doccomment cannot have callable fields")
        }
        guard fields.attributes.isEmpty 
        else 
        {
            throw Entrapta.Error.init("typealias doccomment cannot have attribute fields")
        }
        guard fields.conformances.isEmpty 
        else 
        {
            throw Entrapta.Error.init("typealias doccomment cannot have conformance fields")
        }
        guard fields.dispatch == nil 
        else 
        {
            throw Entrapta.Error.init("typealias doccomment cannot have a dispatch field")
        }
        
        let name:String = header.identifiers.joined(separator: ".")
        let signature:Signature     = .init 
        {
            Signature.text("typealias")
            Signature.whitespace
            Signature.init(joining: header.identifiers, Signature.text(highlighting:))
            {
                Signature.punctuation(".")
            }
            Signature.init(generics: header.generics)
        }
        let declaration:Declaration = .init 
        {
            Declaration.keyword("typealias")
            Declaration.whitespace
            Declaration.identifier(header.identifiers[header.identifiers.endIndex - 1])
            Declaration.init(generics: header.generics)
            Declaration.whitespace(breakable: false)
            Declaration.punctuation("=")
            Declaration.whitespace
            Declaration.init(type: header.target)
            if let clauses:[Grammar.WhereClause]        = fields.constraints?.clauses 
            {
                Declaration.whitespace
                Declaration.init(constraints: clauses) 
            }
        }
        
        let aliased:[[String]]
        switch header.target 
        {
        case .named(let identifiers):
            // strip generic parameters from named type 
            aliased = [identifiers.map(\.identifier)]
        default: 
            aliased = []
        }
        
        try self.init(path: header.identifiers, 
            name:           name, 
            kind:          .typealias(module: .local, generic: !header.generics.isEmpty), 
            signature:      signature, 
            declaration:    declaration, 
            generics:       header.generics,
            aliases:        aliased,
            fields:         fields, 
            order:          order)
    }
    convenience 
    init(_ header:Grammar.AssociatedtypeField, fields:Fields, order:Int) throws 
    {
        // we can infer values for some of the fields 
        var fields:Fields = fields 
        
        guard fields.callable.isEmpty
        else 
        {
            throw Entrapta.Error.init("associatedtype doccomment cannot have callable fields")
        }
        guard fields.attributes.isEmpty 
        else 
        {
            throw Entrapta.Error.init("associatedtype doccomment cannot have attribute fields")
        }
        // this restriction really isn’t necessary, and should be removed eventually 
        guard fields.conformances.isEmpty
        else 
        {
            throw Entrapta.Error.init("associatedtype cannot have conformance fields", 
                help: "write associatedtype constraints in a constraints field.")
        }
        guard fields.dispatch == nil 
        else 
        {
            throw Entrapta.Error.init("associatedtype doccomment cannot have a dispatch field")
        }
        switch (fields.relationships, header.target)
        {
        case (.required?, nil):
            print("warning: relationships field with keyword `required` is redundant for associatedtype '\(header.identifiers.joined(separator: "."))'")
        case (.required?, _?): 
            print("warning: associatedtype '\(header.identifiers.joined(separator: "."))' was marked `required`, but it has a default type")
        case (.defaulted?, nil): 
            print("warning: associatedtype '\(header.identifiers.joined(separator: "."))' was marked `defaulted`, but it has no default type")
        case (.defaulted?, _?): 
            print("warning: relationships field with keyword `defaulted` is redundant for associatedtype '\(header.identifiers.joined(separator: "."))'")
        case (.defaultedConditionally?, _):
            print("warning: associatedtype '\(header.identifiers.joined(separator: "."))' was marked as conditionally `defaulted`, which does not make sense")
        case (.implements?, _):
            print("warning: associatedtype '\(header.identifiers.joined(separator: "."))' was marked as implementing a protocol requirement, which does not make sense")
        case (nil, nil):
            // infer `required`
            fields.update(relationships: .required)
        case (nil, _?):
            // infer `defaulted`
            fields.update(relationships: .defaulted)
        }
        
        // do not print fully-qualified name for associatedtypes 
        let name:String = header.identifiers[header.identifiers.endIndex - 1]
        // if any of the constraints refer to the associatedtype itself, print 
        // them as conformances. 
        // do not use Array.partition(by:), as that sort is non-stable 
        let conformances:[[[String]]] = fields.constraints?.clauses
        .compactMap
        {
            if case ([name], .conforms(let identifiers)) = ($0.subject, $0.predicate)
            {
                return identifiers 
            }
            else 
            {
                return nil 
            }
        } ?? []
        let constraints:[Grammar.WhereClause] = fields.constraints?.clauses 
        .filter 
        {
            if case ([name], .conforms(_)) = ($0.subject, $0.predicate)
            {
                return false  
            }
            else 
            {
                return true 
            }
        } ?? []
        
        let signature:Signature     = .init 
        {
            Signature.text("associatedtype")
            Signature.whitespace
            Signature.text(highlighting: name)
        }
        let declaration:Declaration = .init 
        {
            Declaration.keyword("associatedtype")
            Declaration.whitespace
            Declaration.identifier(name)
            if !conformances.isEmpty 
            {
                Declaration.punctuation(":") 
                Declaration.init(joining: conformances) 
                {
                    Declaration.init(joining: $0, Declaration.init(typename:))
                    {
                        Declaration.whitespace(breakable: false)
                        Declaration.punctuation("&") 
                        Declaration.whitespace(breakable: false)
                    }
                }
                separator:
                {
                    Declaration.punctuation(",") 
                    Declaration.whitespace
                }
            }
            if let target:Grammar.SwiftType = header.target 
            {
                Declaration.whitespace(breakable: false)
                Declaration.punctuation("=")
                Declaration.whitespace
                Declaration.init(type: target)
            }
            if !constraints.isEmpty 
            {
                Declaration.whitespace
                Declaration.init(constraints: constraints) 
            }
        }
        
        try self.init(path: header.identifiers, 
            name:           name, 
            kind:          .associatedtype(module: .local), 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            order:          order)
    }
    convenience 
    init(_ header:Grammar.TypeField, fields:Fields, order:Int) throws 
    {
        guard fields.callable.isEmpty
        else 
        {
            throw Entrapta.Error.init("type doccomment cannot have callable fields")
        }
        switch 
        (
            header.keyword, 
            fields.dispatch, 
            fields.dispatch?.keywords.contains(.override) ?? false
        )
        {
        case (_,      nil,   _), (.class, _?, false): break // okay 
        case (.class, _?, true):
            throw Entrapta.Error.init("type doccomment cannot have a dispatch field with an `override` modifier")
        case (_,      _?,    _):
            throw Entrapta.Error.init("type doccomment can only have a dispatch field if its keyword is `class`")
        }
        
        let kind:Kind
        switch header.keyword
        {
        case .extension:
            guard header.generics.isEmpty 
            else 
            {
                throw Entrapta.Error.init("extension cannot have generic parameters")
            }
            kind = .extension 
        case .protocol:
            guard header.generics.isEmpty 
            else 
            {
                throw Entrapta.Error.init("protocol cannot have generic parameters")
            }
            kind = .protocol        (module: .local) 
        case .class:
            kind = .class           (module: .local, generic: !header.generics.isEmpty) 
        case .struct:
            kind = .struct          (module: .local, generic: !header.generics.isEmpty) 
        case .enum:
            kind = .enum            (module: .local, generic: !header.generics.isEmpty) 
        }
        
        // only put universal conformances in the declaration 
        let conformances:[[[String]]] = fields.conformances.compactMap 
        {
            $0.conditions.isEmpty ? $0.conformances : nil 
        }
        if  case .extension = header.keyword, 
            conformances.count != fields.conformances.count
        {
            throw Entrapta.Error.init("extension cannot have conditional conformances", 
                help: 
                """
                write the conformances as unconditional conformances, and use a \
                constraints field to specify their conditions.
                """)
        }
        
        let signature:Signature     = .init 
        {
            Signature.text("\(header.keyword)")
            Signature.whitespace
            Signature.init(joining: header.identifiers, Signature.text(highlighting:))
            {
                Signature.punctuation(".")
            }
            Signature.init(generics: header.generics)
            // include conformances in signature, if extension 
            if case .extension = header.keyword, !conformances.isEmpty
            {
                Signature.punctuation(":") 
                Signature.init(joining: conformances) 
                {
                    Signature.init(joining: $0)
                    {
                        Signature.init(joining: $0, Signature.text(_:))
                        {
                            Signature.punctuation(".") 
                        }
                    }
                    separator:
                    {
                        Signature.whitespace
                        Signature.punctuation("&") 
                        Signature.whitespace
                    }
                }
                separator:
                {
                    Signature.punctuation(",") 
                    Signature.whitespace
                }
            }
        }
        let declaration:Declaration = .init 
        {
            Declaration.init(attributes: fields.attributes)
            if let dispatch:Grammar.DispatchField       = fields.dispatch 
            {
                Declaration.init(modifiers: dispatch)
                Declaration.whitespace 
            }
            Declaration.keyword("\(header.keyword)")
            Declaration.whitespace
            if      case .extension                     = header.keyword 
            {
                Declaration.init(typename: header.identifiers)
            }
            else if let last:String                     = header.identifiers.last  
            {
                Declaration.identifier(last)
            }
            Declaration.init(generics: header.generics)
            if !conformances.isEmpty 
            {
                Declaration.punctuation(":") 
                Declaration.init(joining: conformances) 
                {
                    Declaration.init(joining: $0, Declaration.init(typename:))
                    {
                        Declaration.whitespace(breakable: false)
                        Declaration.punctuation("&") 
                        Declaration.whitespace(breakable: false)
                    }
                }
                separator:
                {
                    Declaration.punctuation(",") 
                    Declaration.whitespace
                }
            }
            if let clauses:[Grammar.WhereClause]        = fields.constraints?.clauses 
            {
                Declaration.whitespace
                Declaration.init(constraints: clauses) 
            }
        }
        
        try self.init(path: header.identifiers, 
            name:           header.identifiers.joined(separator: "."), 
            kind:           kind, 
            signature:      signature, 
            declaration:    declaration, 
            generics:       header.generics,
            fields:         fields, 
            order:          order)
    }
}

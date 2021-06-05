struct Symbol 
{
    struct Pseudo 
    {
        let kind:Page.Kind 
        let anchor:Page.Anchor 
        let generics:[String] 
        
        let fields:Page.Fields 
        
        init(kind:Page.Kind, anchor:[String], generics:[String] = [], fields:Page.Fields)
        {
            self.kind       = kind 
            self.anchor     = .external(path: anchor)
            self.generics   = generics 
            self.fields     = fields
        }
    }
    
    let header:Grammar.HeaderField 
    let fields:Page.Fields 
    
    init(_ comment:Grammar.DocumentationComment, order:Int) throws 
    {
        self.header = comment.header 
        self.fields = try .init(comment, order: order)
    }
}

extension Page 
{
    struct Fields
    {
        struct Callable 
        {
            let domain:[(type:Grammar.FunctionParameter, paragraphs:[Paragraph], name:String)]
            let range:(type:Grammar.SwiftType, paragraphs:[Paragraph])?
            
            var isEmpty:Bool 
            {
                self.domain.isEmpty && self.range == nil 
            }
            
            func print(labels:[String]) -> String 
            {
                zip(self.domain, labels).map
                { 
                    switch ($0.0.type.variadic, $0.1)
                    {
                    case (true, "_"):           return "...:"
                    case (true,  let label):    return "\(label)...:"
                    case (false, let label):    return "\(label):"
                    }
                }.joined()
            }
        }
        
        enum Relationships 
        {
            case required
            case defaulted 
            case defaultedConditionally([[Grammar.WhereClause]]) 
            case implements([Grammar.ImplementationField])
        }
        
        var path:[String]
        
        let attributes:[Grammar.AttributeField], 
            conformances:[Grammar.ConformanceField], 
            constraints:Grammar.ConstraintsField?, 
            dispatch:Grammar.DispatchField? 
        
        let callable:Callable
        private(set)
        var relationships:Relationships?
        
        let paragraphs:[Paragraph]
        
        let priority:(rank:Int, order:Int), 
            topics:[(name:String, keys:[String])], 
            memberships:[(topic:String, rank:Int, order:Int)]
            
        var blurb:Paragraph?
        {
            self.paragraphs.first
        }
        var discussion:[Paragraph]
        {
            .init(self.paragraphs.dropFirst())
        }
    }
}
extension Page.Fields 
{
    // used for standard library symbols 
    init(path:[String], 
        constraints:Grammar.ConstraintsField?   = nil, 
        conformances:[Grammar.ConformanceField] = []) 
    {
        self.path           = path 
        
        self.attributes     = []
        self.constraints    = constraints 
        self.conformances   = conformances
        self.dispatch       = nil 
        self.callable       = .init(domain: [], range: nil)
        self.relationships  = nil 
        self.paragraphs     = []
        self.priority       = (0, .max)
        self.topics         = []
        self.memberships    = []
    }
    
    init(_ comment:Grammar.DocumentationComment, order:Int) throws 
    {
        typealias ParameterDescription = 
        (
            parameter:Grammar.ParameterField, 
            paragraphs:[Paragraph]
        )
        
        var attributes:[Grammar.AttributeField]             = [], 
            conformances:[Grammar.ConformanceField]         = [], 
            constraints:Grammar.ConstraintsField?           = nil, 
            dispatch:Grammar.DispatchField?                 = nil
         
        var parameters:[ParameterDescription]               = [] 
        
        var implementations:[Grammar.ImplementationField]   = [],
            requirements:[Grammar.RequirementField]         = [] 
            
        var paragraphs:[Paragraph]                          = []
        
        // compute priorities, topics, and topic memberships, and gather other fields
        var priority:(rank:Int, order:Int)?                     = nil 
        var topics:[(name:String, keys:[String])]               = [], 
            memberships:[(topic:String, rank:Int, order:Int)]   = []
        for field:Grammar.AuxillaryField in comment.fields
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
                    paragraphs.append(contentsOf: field.paragraphs)
                }
                else 
                {
                    parameters[parameters.endIndex - 1].paragraphs.append(contentsOf: field.paragraphs)
                }
            
            case .topic             (let field):
                topics.append((field.display, field.keys))
            case .topicMembership   (let field):
                // empty rank corresponds to zero. should sort in 
                // (0:)
                // (1:)
                // (2:)
                // (3:)
                // ...
                // (-2:)
                // (-1:)
                let rank:Int = field.rank.map{ ($0 < 0 ? .max : .min) + $0 } ?? 0
                if let topic:String = field.key 
                {
                    memberships.append((topic, rank, order))
                }
                else if let _:(rank:Int, order:Int) = priority 
                {
                    throw Entrapta.Error.init("only one anonymous topic element field allowed per symbol")
                }
                else 
                {
                    priority = (rank, order)
                }
            
            case .parameter     (let field):
                parameters.append((field, []))
            
            case .dispatch      (let field):
                guard dispatch == nil 
                else 
                {
                    throw Entrapta.Error.init("only one dispatch field per doccomnent allowed")
                }
                dispatch = field 
            
            case .separator:
                break
            }
        }
        // if there is no anonymous topic element field, we want to sort 
        // the symbols alphabetically, so we set the order to max. this will 
        // put it after any topic elements with an empty membership field (`#()`), 
        // which appear in declaration-order
        self.priority       = priority ?? (0, .max)
        self.memberships    = memberships
        self.topics         = topics
        
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
        let range:(type:Grammar.SwiftType, paragraphs:[Paragraph])?
        if  let last:ParameterDescription   = parameters.last, 
            case .return                    = last.parameter.name
        {
            range = (last.parameter.parameter.type, last.paragraphs)
            parameters.removeLast()
        }
        else 
        {
            range = nil 
        }
        let domain:[(type:Grammar.FunctionParameter, paragraphs:[Paragraph], name:String)] = 
            try parameters.map 
        {
            guard case .parameter(let name) = $0.parameter.name 
            else 
            {
                throw Entrapta.Error.init("return value must be the last parameter field")
            }
            return ($0.parameter.parameter, $0.paragraphs, name)
        }
        
        self.callable = .init(domain: domain, range: range)
        
        self.paragraphs         = paragraphs
        
        // compute the path 
        switch comment.header 
        {
        case .framework:
            self.path = []
        case .dependency    (.module(            identifier:  let identifier)):
            self.path = [identifier]
        case .dependency    (.type  (keyword: _, identifiers: let identifiers)):
            self.path = identifiers
        case .lexeme        (let header):
            self.path = ["\(header.keyword) operator \(header.lexeme)"] 
        
        case .function      (let header):
            let suffix:String? = header.labels.map(self.callable.print(labels:))
            let name:String 
            switch (header.identifiers.tail, suffix)
            {
            case (.alphanumeric("callAsFunction"), let suffix?):    name =                   "(\(suffix))"
            case (let basename,                    let suffix?):    name = "\(basename.string)(\(suffix))"
            case (let basename,                    nil        ):    name =    basename.string
            }
            self.path = header.identifiers.prefix + [name]
        case .subscript     (let header):
            let name:String = "[\(self.callable.print(labels: header.labels))]"
            self.path = header.identifiers        + [name]
        case .property      (let header):
            self.path = header.identifiers
        case .associatedtype(let header):
            self.path = header.identifiers
        case .typealias     (let header):
            self.path = header.identifiers
        case .type          (let header):
            self.path = header.identifiers
        }
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
    init(_ header:Grammar.FrameworkField, fields:Fields) throws 
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
        self.init(parent: nil, kind: kind, fields: fields,
            name:           header.identifier, 
            signature:      .empty, 
            declaration:    .empty)
    }
    convenience 
    init(_ header:Grammar.DependencyField, fields:Fields, parent:InternalNode) throws
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
        }
        self.init(parent: parent, kind: kind, fields: fields,
            name:           name, 
            signature:      signature, 
            declaration:    declaration)
    }
    convenience 
    init(_ header:Grammar.LexemeField, fields:Fields, parent:InternalNode) throws
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
        self.init(parent: parent, kind: .lexeme(module: .local), fields: fields, 
            name:           header.lexeme, 
            signature:      signature, 
            declaration:    declaration)
    }
    convenience 
    init(_ header:Grammar.SubscriptField, fields:Fields, parent:InternalNode) throws 
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
        
        let signature:Signature     = .init 
        {
            Signature.text(highlighting: "subscript")
            Signature.init(generics: header.generics)
            Signature.init(callable: fields.callable, labels: header.labels, throws: nil, 
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
            Declaration.init(callable: fields.callable, labels: header.labels, throws: nil)
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
        
        self.init(parent: parent, kind: .subscript(generic: !header.generics.isEmpty), 
            generics:       header.generics,
            fields:         fields,
            name:           fields.path[fields.path.endIndex - 1], 
            signature:      signature, 
            declaration:    declaration)
    }
    convenience 
    init(_ header:Grammar.FunctionField, fields:Fields, parent:InternalNode) throws 
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
        case    (.`init`,               .alphanumeric("init")), 
                (.requiredInit,         .alphanumeric("init")), 
                (.convenienceInit,      .alphanumeric("init")): // okay 
            break
        case    (.`init`,               _), 
                (.requiredInit,         _), 
                (.convenienceInit,      _): 
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
            fields.callable.domain.map(\.name) == header.labels ?? [],
            fields.callable.domain.allSatisfy{ !$0.type.variadic } 
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
        case .requiredInit:     keywords = []
        case .convenienceInit:  keywords = []
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
        case    (.`init`,               _, _           ), 
                (.requiredInit,         _, _           ), 
                (.convenienceInit,      _, _           ):   
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
            case (.`init`, _), (.requiredInit, _), (.convenienceInit, _):
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
            if let labels:[String] = header.labels
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
            case    (.requiredInit, _):
                Declaration.keyword("required")
                Declaration.whitespace
                Declaration.keyword("init")
            case    (.convenienceInit, _):
                Declaration.keyword("convenience")
                Declaration.whitespace
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
            if let labels:[String] = header.labels
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
        
        self.init(parent:   parent, kind: kind, 
            generics:       header.generics, 
            fields:         fields, 
            name:           fields.path[fields.path.endIndex - 1], 
            signature:      signature, 
            declaration:    declaration)
    }
    convenience 
    init(_ header:Grammar.PropertyField, fields:Fields, parent:InternalNode) throws 
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
        case (.var, _), (.classVar, _), (.let, _), (_, nil):   break // okay 
        case (_, _?):
            throw Entrapta.Error.init(
                "property doccomment can only have a dispatch field if its keyword is `let`, `var`, or `class var`") 
        }
        switch (header.keyword, header.accessors)
        {
        case (.var, _), (.classVar, _), (.staticVar, _), (_, nil):   break // okay 
        case (_, _?):
            throw Entrapta.Error.init(
                "property doccomment can only have accessors if keyword is `var`, `class var`, or `static var`") 
        }
        
        let name:String = fields.path[fields.path.endIndex - 1] 
        
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
        case .classVar:
            kind        = .classProperty 
            keywords    = ["class", "var"]
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
        
        self.init(parent:   parent, kind: kind, 
            fields:         fields,
            name:           name, 
            signature:      signature, 
            declaration:    declaration)
    }
    convenience 
    init(_ header:Grammar.TypealiasField, fields:Fields, parent:InternalNode) throws 
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
        
        // use this because it does not necessarily contain `Swift` prefix
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
        
        self.init(parent:   parent, 
            kind:          .typealias(module: .local, generic: !header.generics.isEmpty), 
            generics:       header.generics,
            aliases:        aliased,
            fields:         fields,
            name:           name, 
            signature:      signature, 
            declaration:    declaration)
    }
    convenience 
    init(_ header:Grammar.AssociatedtypeField, fields:Fields, parent:InternalNode) throws 
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
        let name:String = fields.path[fields.path.endIndex - 1] 
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
        
        self.init(parent:   parent, kind: .associatedtype(module: .local), 
            fields:         fields,
            name:           name, 
            signature:      signature, 
            declaration:    declaration)
    }
    convenience 
    init(_ header:Grammar.TypeField, fields:Fields, parent:InternalNode) throws 
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
        
        // get “deep” generics 
        let deep:[[String]] = (parent.ancestors.dropFirst() + [parent])
            .map(\.page.parameters)
            + 
            [header.generics]
        
        let signature:Signature     = .init 
        {
            Signature.text("\(header.keyword)")
            Signature.whitespace
            Signature.init(joining: zip(header.identifiers, deep))
            {
                Signature.text(highlighting: $0.0)
                Signature.init(generics:     $0.1)
            } 
            separator:
            {
                Signature.punctuation(".")
            }
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
        
        self.init(parent:   parent, kind: kind, 
            generics:       header.generics,
            fields:         fields, 
            // use this to omit `Swift` prefix if not written explicitly 
            name:           header.identifiers.joined(separator: "."), 
            signature:      signature, 
            declaration:    declaration)
    }
}

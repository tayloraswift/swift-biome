enum Link:Hashable
{    
    case unresolved(path:[String])
    case resolved(url:String, module:Module)
    
    static 
    let optional:Self   = .init(builtin: ["Swift", "Optional"]),
        array:Self      = .init(builtin: ["Swift", "Array"]),
        dictionary:Self = .init(builtin: ["Swift", "Dictionary"])
    
    static 
    let metatype:Self   = .resolved(
        url:   "https://docs.swift.org/swift-book/ReferenceManual/Types.html#ID455", 
        module: .swift)
    
    init<C>(builtin path:C) 
        where C:Collection, C.Element == String
    {
        self = .resolved(url: 
            "https://developer.apple.com/documentation/\(path.map{ $0.lowercased() }.joined(separator: "/"))", 
            module: .swift)
    } 
    
    static 
    func scan<C>(_ elements:C) -> [(element:String, link:Self)]
        where C:RandomAccessCollection, C.Element == String 
    {
        Self.scan(\.self, in: elements)
    }
    static 
    func scan<C>(_ accessor:KeyPath<C.Element, String>, in elements:C) 
        -> [(element:C.Element, link:Self)]
        where C:RandomAccessCollection 
    {
        let result:[(element:C.Element, link:Self)] = elements.enumerated().map 
        {
            (
                $0.1, 
                .unresolved(path: elements.prefix($0.0 + 1).map{ $0[keyPath: accessor] })
            )
        }
        
        let trimmed:ArraySlice<(element:C.Element, link:Self)> 
        // strip `Swift` prefix 
        if result.first?.element[keyPath: accessor] == "Swift" 
        {
            trimmed = result.dropFirst()
        } 
        else 
        {
            trimmed = result[...]
        }
        // metatypes 
        if  let last:C.Element = trimmed.last?.element, 
                last[keyPath: accessor]             == "Type" 
        {
            return trimmed.dropLast() + [(last, .metatype)]
        }
        else 
        {
            return .init(trimmed)
        }
    }
}

@resultBuilder
struct Declaration:CodeBuilder 
{
    enum Token:Equatable
    {
        case keyword(String)
        case identifier(String, Link?)
        case punctuation(String, Link?)
        case whitespace(breakable:Bool)
    }
    
    let tokens:[Token]
    
    init(tokens:[Token])
    {
        self.tokens = tokens 
    }
}
extension Declaration 
{
    static 
    var whitespace:Self 
    {
        Self.whitespace(breakable: true)
    }
    static 
    func whitespace(breakable:Bool) -> Self 
    {
        .init(tokens: [.whitespace(breakable: breakable)])
    }
    static 
    func keyword(_ string:String) -> Self 
    {
        .init(tokens: [.keyword(string)])
    }
    static 
    func identifier(_ string:String) -> Self 
    {
        .init(tokens: [.identifier(string, nil)])
    }
    static 
    func identifier(_ string:String, link:Link) -> Self 
    {
        .init(tokens: [.identifier(string, link)])
    }
    static 
    func punctuation(_ string:String) -> Self 
    {
        .init(tokens: [.punctuation(string, nil)])
    }
    static 
    func punctuation(_ string:String, link:Link) -> Self 
    {
        .init(tokens: [.punctuation(string, link)])
    }
    
    init(@Declaration _ build:() -> Self) 
    {
        self = build()
    }
    
    init<S>(joining elements:S, 
        @Declaration _ transform    :(S.Element) -> Self, 
        @Declaration separator      :() -> Self, 
        @Declaration left           :() -> Self = { .empty }, 
        @Declaration right          :() -> Self = { .empty })
        where S:Sequence
    {
        let segments:[[Self]] = elements.map{ [transform($0)] }
        if segments.isEmpty 
        {
            self.init(tokens: [])
        }
        else 
        {
            self.init 
            {
                left()
                for segment:Self in segments.joined(separator: [separator()])
                {
                    segment 
                }
                right()
            }
        }
    }
    
    init<C>(typename:C) 
        where C:RandomAccessCollection, C.Element == String
    {
        self.init(joining: Link.scan(typename)) 
        {
            Self.identifier($0.element, link: $0.link)
        }
        separator: 
        {
            Self.punctuation(".")
        }
    }
    
    init(type:Grammar.SwiftType) 
    {
        switch type 
        {
        case .named(let identifiers):
            if      identifiers.count           == 2, 
                    identifiers[0].identifier   == "Swift",
                    identifiers[0].generics.isEmpty
            {
                if      identifiers[1].identifier       == "Optional", 
                        identifiers[1].generics.count   == 1
                {
                    self.init
                    {
                        Self.init(type: identifiers[1].generics[0])
                        Self.punctuation("?", link: .optional)
                    }
                    return 
                }
                else if identifiers[1].identifier       == "Array", 
                        identifiers[1].generics.count   == 1
                {
                    self.init
                    {
                        Self.punctuation("[", link: .array)
                        Self.init(type: identifiers[1].generics[0])
                        Self.punctuation("]", link: .array)
                    }
                    return 
                }
                else if identifiers[1].identifier       == "Dictionary", 
                        identifiers[1].generics.count   == 2
                {
                    self.init
                    {
                        Self.punctuation("[", link: .dictionary)
                        Self.init(type: identifiers[1].generics[0])
                        Self.punctuation(":", link: .dictionary)
                        Self.init(type: identifiers[1].generics[1])
                        Self.punctuation("]", link: .dictionary)
                    }
                    return 
                }
            }
            
            self.init(joining: Link.scan(\.identifier, in: identifiers)) 
            {
                Self.identifier($0.element.identifier, link: $0.link)
                Self.init(joining: $0.element.generics)
                {
                    Self.init(type: $0)
                }
                separator: 
                {
                    Self.punctuation(",")
                    Self.whitespace
                }
                left: 
                {
                    Self.punctuation("<")
                }
                right: 
                {
                    Self.punctuation(">")
                }
            }
            separator: 
            {
                Self.punctuation(".")
            }
        
        case .compound(let elements):
            self.init 
            {
                Self.punctuation("(")
                Self.init(joining: elements) 
                {
                    if let label:String = $0.label 
                    {
                        Self.identifier(label)
                        Self.punctuation(":")
                    }
                    Self.init(type: $0.type)
                }
                separator: 
                {
                    Self.punctuation(",")
                    Self.whitespace
                }
                Self.punctuation(")")
            }
        
        case .function(let function):
            self.init 
            {
                for attribute:Grammar.Attribute in function.attributes
                {
                    Self.keyword("\(attribute)")
                    Self.whitespace
                }
                Self.punctuation("(")
                Self.init(joining: function.parameters) 
                {
                    for attribute:Grammar.Attribute in $0.attributes
                    {
                        Self.keyword("\(attribute)")
                        Self.whitespace(breakable: false)
                    }
                    if $0.inout 
                    {
                        Self.keyword("inout")
                        Self.whitespace(breakable: false)
                    }
                    Self.init(type: $0.type)
                }
                separator: 
                {
                    Self.punctuation(",")
                    Self.whitespace
                }
                Self.punctuation(")")
                Self.whitespace
                if function.throws 
                {
                    Self.keyword("throws")
                    Self.whitespace
                }
                Self.keyword("->")
                Self.whitespace(breakable: false)
                Self.init(type: function.return)
            }
        
        case .protocols(let protocols):
            self.init(joining: protocols) 
            {
                Self.init(typename: $0)
            }
            separator: 
            {
                Self.whitespace(breakable: false)
                Self.punctuation("&")
                Self.whitespace(breakable: false)
            }
        }    
    } 
    
    init(accessors:Grammar.Accessors) 
    {
        self.init 
        {
            Self.punctuation("{")
            Self.whitespace(breakable: false)
            Self.keyword("get")
            if case .settable(nonmutating: let nonmutating) = accessors
            {
                if nonmutating
                {
                    Self.whitespace(breakable: false)
                    Self.keyword("nonmutating")
                }
                Self.whitespace(breakable: false)
                Self.keyword("set")
            }
            Self.whitespace(breakable: false)
            Self.punctuation("}")
        }
    }
    
    // includes trailing whitespace 
    init(attributes:[Grammar.AttributeField]) 
    {
        self.init 
        {
            for attribute:Grammar.AttributeField in attributes 
            {
                switch attribute
                {
                case .frozen, .inlinable, .discardableResult, .resultBuilder, .propertyWrapper:
                    Self.keyword("@\(attribute)")
                    Self.whitespace
                case .custom(let type):
                    Self.keyword("@")
                    Self.init(type: type)
                    Self.whitespace
                case .specialized(let clauses):
                    Self.keyword("@_specialized")
                    Self.punctuation("(")
                    Self.init(constraints: clauses)
                    Self.punctuation(")")
                }
            }
        }
    }
    
    init(modifiers dispatch:Grammar.DispatchField?) 
    {
        guard let dispatch:Grammar.DispatchField = dispatch 
        else 
        {
            self.init(tokens: [])
            return 
        }
        // iterate this way to always print the keywords in the correct order 
        self.init(joining: Grammar.DispatchField.Keyword.allCases.filter(dispatch.keywords.contains(_:))) 
        {
            Self.keyword("\($0)")
        }
        separator: 
        {
            Self.whitespace
        }
    }
    
    init(generics:[String]) 
    {
        self.init(joining: generics, Self.identifier(_:))
        {
            Self.punctuation(",")
            Self.whitespace
        }
        left: 
        {
            Self.punctuation("<")
        }
        right: 
        {
            Self.punctuation(">")
        }
    }
    
    init(constraints clauses:[Grammar.WhereClause]) 
    {
        self.init 
        {
            Self.keyword("where")
            Self.whitespace(breakable: false)
            Self.init(joining: clauses) 
            {
                Self.init(typename: $0.subject)
                switch $0.predicate 
                {
                case .conforms(let protocols):
                    Self.punctuation(":")
                    Self.init(type: .protocols(protocols))
                case .equals(let type):
                    Self.whitespace(breakable: false)
                    Self.punctuation("==")
                    Self.whitespace(breakable: false)
                    Self.init(type: type)
                }
            }
            separator: 
            {
                Self.punctuation(",")
                Self.whitespace
            }
        }
    }
    
    init(callable:Node.Page.Fields.Callable, labels:[(name:String, variadic:Bool)], 
        throws:Grammar.FunctionField.Throws?, 
        unifier:(String, String) -> [String])
    {
        precondition(labels.count == callable.domain.count)
        self.init 
        {
            Self.punctuation("(")
            Self.init(joining: zip(labels, callable.domain.map{ ($0.name, $0.type) }))
            {
                let (label, variadic):(String, Bool)                        = $0.0
                let (name, parameter):(String, Grammar.FunctionParameter)   = $0.1
                
                let unified:[String] = unifier(label, name)
                if !unified.isEmpty 
                {
                    Self.init(joining: unified)
                    {
                        $0 == "_" ? Self.keyword($0) : Self.identifier($0)
                    }
                    separator:
                    {
                        Self.whitespace(breakable: false)
                    }
                    Self.punctuation(":")
                }
                for attribute:Grammar.Attribute in parameter.attributes
                {
                    Self.keyword("\(attribute)")
                    Self.whitespace(breakable: false)
                }
                if parameter.inout 
                {
                    Self.keyword("inout")
                    Self.whitespace(breakable: false)
                }
                Self.init(type: parameter.type)
                if variadic 
                {
                    for _:Int in 0 ..< 3 
                    {
                        Self.punctuation(".")
                    }
                } 
            }
            separator: 
            {
                Self.punctuation(",")
                Self.whitespace
            } 
            Self.punctuation(")")
            
            if let `throws`:Grammar.FunctionField.Throws = `throws`
            {
                Self.whitespace
                Self.keyword("\(`throws`)")
            }
            if let type:Grammar.SwiftType       = callable.range?.type 
            {
                Self.whitespace
                Self.punctuation("->")
                Self.whitespace(breakable: false)
                Self.init(type: type)
            } 
        }
    }
}

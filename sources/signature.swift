@resultBuilder
struct Signature:CodeBuilder
{
    enum Token:Equatable
    {
        case text       (String, highlight:Bool)
        case punctuation(String, highlight:Bool)
        case whitespace 
    }
    
    let tokens:[Token]
    
    init(tokens:[Token])
    {
        self.tokens = tokens 
    }
}
extension Signature 
{
    static 
    var whitespace:Self 
    {
        .init(tokens: [.whitespace])
    }
    static 
    func text(_ string:String) -> Self 
    {
        .init(tokens: [.text(string, highlight: false)])
    }
    static 
    func text(highlighting string:String) -> Self 
    {
        .init(tokens: [.text(string, highlight: true)])
    }
    static 
    func punctuation(_ string:String) -> Self 
    {
        .init(tokens: [.punctuation(string, highlight: false)])
    }
    
    init(@Signature _ build:() -> Self) 
    {
        self = build()
    }
    
    init<S>(joining elements:S, 
        @Signature _ transform  :(S.Element) -> Self, 
        @Signature separator    :() -> Self, 
        @Signature left         :() -> Self = { .empty }, 
        @Signature right        :() -> Self = { .empty })
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
    
    private 
    init(converting declaration:Declaration) 
    {
        self.init 
        {
            for token:Declaration.Token in declaration.tokens 
            {
                switch token  
                {
                case .keyword(let text): 
                    Self.text(text)
                case .identifier(let text, _):  
                    Self.text(text)
                case .punctuation(let text, _):  
                    Self.punctuation(text)
                case .whitespace(breakable: _):
                    Self.whitespace
                }
            }
        }
    }
    
    init(type:Grammar.SwiftType) 
    {
        self.init(converting: .init(type: type))
    }
    
    init(constraints clauses:[Grammar.WhereClause]) 
    {
        self.init(converting: .init(constraints: clauses))
    }
    
    init(generics:[String]) 
    {
        self.init(joining: generics, Self.text(_:))
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
    
    init(callable:Page.Fields.Callable, labels:[String], 
        throws:Grammar.FunctionField.Throws?, 
        delimiters:(String, String))
    {
        guard labels.count == callable.domain.count 
        else 
        {
            fatalError("error: callable has \(labels.count) labels, but \(callable.domain.count) parameters")
        }
        
        self.init 
        {
            Self.punctuation(delimiters.0)
            Self.init(joining: zip(labels, callable.domain.map(\.type)))
            {
                let (label, parameter):(String, Grammar.FunctionParameter) = $0
                
                if label != "_" 
                {
                    Self.text(highlighting: label)
                    Self.punctuation(":")
                }
                if parameter.inout 
                {
                    Self.text("inout")
                    Self.whitespace
                }
                Self.init(type: parameter.type)
                if parameter.variadic 
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
            Self.punctuation(delimiters.1)
            
            if let `throws`:Grammar.FunctionField.Throws = `throws`
            {
                Self.whitespace
                Self.text("\(`throws`)")
            }
            if let type:Grammar.SwiftType       = callable.range?.type 
            {
                Self.whitespace
                Self.punctuation("->")
                Self.whitespace
                Self.init(type: type)
            } 
        }
    }
}

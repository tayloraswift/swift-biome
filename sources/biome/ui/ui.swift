import HTML

extension HTML 
{
    static 
    func render(constraints:[Generic.Constraint<Symbol.Index>]) 
        -> [Element<Ecosystem.Index>] 
    {
        guard let ultimate:Generic.Constraint<Symbol.Index> = constraints.last 
        else 
        {
            fatalError("cannot call \(#function) with empty constraints array")
        }
        guard let penultimate:Generic.Constraint<Symbol.Index> = constraints.dropLast().last
        else 
        {
            return Self.render(constraint: ultimate)
        }
        var elements:[Element<Ecosystem.Index>]
        if constraints.count < 3 
        {
            elements =                  Self.render(constraint: penultimate)
            elements.append(.text(escaped: " and "))
            elements.append(contentsOf: Self.render(constraint: ultimate))
        }
        else 
        {
            elements = []
            for constraint:Generic.Constraint<Symbol.Index> in constraints.dropLast(2)
            {
                elements.append(contentsOf: Self.render(constraint: constraint))
                elements.append(.text(escaped: ", "))
            }
            elements.append(contentsOf: Self.render(constraint: penultimate))
            elements.append(.text(escaped: ", and "))
            elements.append(contentsOf: Self.render(constraint: ultimate))
        }
        return elements
    }
    static 
    func render(constraint:Generic.Constraint<Symbol.Index>) 
        -> [Element<Ecosystem.Index>]
    {
        let verb:String
        switch constraint.verb
        {
        case .subclasses: 
            verb = " inherits from "
        case .implements:
            verb = " conforms to "
        case .is:
            verb = " is "
        }
        let subject:Element<Ecosystem.Index> = 
            .code(.highlight(escaping: constraint.subject, .type))
        let object:Element<Ecosystem.Index> 
        if let index:Symbol.Index = constraint.link 
        {
            object = .a(.code(.highlight(escaping: constraint.object, .type)))
            {
                ("href", .anchor(.symbol(index)))
            }
        }
        else 
        {
            object = .code(.highlight(escaping: constraint.object, .type))
        }
        return [subject, .text(escaped: verb), object]
    }
}

extension DOM.Element where Domain == HTML 
{
    static 
    func highlight(escaping string:String, _ color:Fragment.Color) -> Self
    {
        Self.highlight(.text(escaping: string), color)
    }
    static 
    func highlight(_ child:Self, _ color:Fragment.Color) -> Self
    {
        let classes:String
        switch color
        {
        case .text: 
            return child
        case .type:
            classes = "syntax-type"
        case .identifier:
            classes = "syntax-identifier"
        case .generic:
            classes = "syntax-generic"
        case .argument:
            classes = "syntax-parameter-label"
        case .parameter:
            classes = "syntax-parameter-name"
        case .directive, .attribute, .keywordText:
            classes = "syntax-keyword"
        case .keywordIdentifier:
            classes = "syntax-keyword syntax-keyword-identifier"
        case .pseudo:
            classes = "syntax-pseudo-identifier"
        case .number, .string:
            classes = "syntax-literal"
        case .interpolation:
            classes = "syntax-interpolation-anchor"
        case .keywordDirective:
            classes = "syntax-macro"
        case .newlines:
            classes = "syntax-newline"
        case .comment, .documentationComment:
            classes = "syntax-comment"
        case .invalid:
            classes = "syntax-invalid"
        }
        return .span(child) { ("class", classes) }
    } 
}

import HTML
import Notebook

extension DOM.Element where Domain == HTML
{
    static 
    func highlight<Fragments, Link>(_ fragments:Fragments, 
        _ anchor:(Link) throws -> Anchor) 
        rethrows -> [Self]
        where   Fragments:Sequence, 
                Fragments.Element == Notebook<Highlight, Link>.Fragment
    {
        try fragments.map 
        {
            .highlight(escaping: $0.text, $0.color, href: try $0.link.map(anchor))
        }
    }
    static 
    func highlight(escaping string:String, _ color:Highlight, href anchor:Anchor?) 
        -> Self
    {
        if let anchor:Anchor = anchor
        {
            return .a(.highlight(escaping: string, color))
            {
                ("href", .anchor(anchor))
            }
        }
        else 
        {
            return .highlight(escaping: string, color)
        }
    }
}
extension DOM.Element where Domain == HTML 
{
    static 
    func highlight(escaping string:String, _ color:Highlight) -> Self
    {
        Self.highlight(.text(escaping: string), color)
    }
    static 
    func highlight(_ child:Self, _ color:Highlight) -> Self
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

extension DOM.Element where Domain == HTML
{
    static 
    func render<Fragments, Link>(fragments:Fragments, 
        _ anchor:(Link) throws -> Anchor) 
        rethrows -> Self
        where   Fragments:Sequence, 
                Fragments.Element == Notebook<Highlight, Link>.Fragment
    {
        let fragments:[Self] = try Self.highlight(fragments, anchor)
        let code:Self = .code(fragments) { ("class", "swift") }
        return .section(.pre(code)) { ("class", "declaration") }
    }
    static 
    func render<Fragments>(signature:Fragments) -> Self
        where   Fragments:Sequence, 
                Fragments.Element == Notebook<Highlight, Never>.Fragment
    {
        return .code(Self.highlight(signature) { (_:Never) -> Anchor in })
    }
}

extension DOM.Element where Domain == HTML
{
    static 
    func render(path:Path) -> Self
    {
        var components:[Self] = []
            components.reserveCapacity(2 * path.count - 1)
        for component:String in path.prefix
        {
            components.append(.highlight(escaping: component, .identifier))
            components.append(.highlight(.text(escaped: "."), .text))
        }
        components.append(.highlight(escaping: path.last, .identifier))
        return .code(components)
    }
}
extension DOM.Element where Domain == HTML
{
    static 
    func render(_ prefix:Self, constraints:[Generic.Constraint<Symbol.Index>], 
        _ anchor:(Symbol.Index) throws -> Anchor) 
        rethrows -> Self
    {
        guard let ultimate:Generic.Constraint<Symbol.Index> = constraints.last 
        else 
        {
            fatalError("cannot call \(#function) with empty constraints array")
        }
        guard let penultimate:Generic.Constraint<Symbol.Index> = constraints.dropLast().last
        else 
        {
            return .p(try [prefix] + Self.render(constraint: ultimate, anchor))
        }
        var elements:[Self] 
        if constraints.count < 3 
        {
            elements = try [prefix] + Self.render(constraint: penultimate, anchor)
            elements.append(.text(escaped: " and "))
            elements.append(contentsOf: try Self.render(constraint: ultimate, anchor))
        }
        else 
        {
            elements = []
            for constraint:Generic.Constraint<Symbol.Index> in constraints.dropLast(2)
            {
                elements.append(contentsOf: try Self.render(constraint: constraint, anchor))
                elements.append(.text(escaped: ", "))
            }
            elements.append(contentsOf: try Self.render(constraint: penultimate, anchor))
            elements.append(.text(escaped: ", and "))
            elements.append(contentsOf: try Self.render(constraint: ultimate, anchor))
        }
        return .p(elements)
    }
    static 
    func render(constraint:Generic.Constraint<Symbol.Index>, 
        _ anchor:(Symbol.Index) throws -> Anchor) rethrows -> [Self]
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
        let subject:Self = .code(.highlight(escaping: constraint.subject, .type))
        let object:Self = .code(.highlight(escaping: constraint.object, .type, 
            href: try constraint.link.map(anchor)))
        return [subject, .text(escaped: verb), object]
    }
}

extension DOM.Element where Domain == HTML
{
    private static 
    func render(availability:UnversionedAvailability?) -> Self?
    {
        guard let availability:UnversionedAvailability = availability
        else 
        {
            return nil 
        }
        let adjective:String 
        if availability.unavailable 
        {
            adjective = "Unavailable"
        }
        else if availability.deprecated 
        {
            adjective = "Deprecated"
        }
        else 
        {
            return nil
        }
        return .li { "\(adjective, as: .strong)" }
    }
    private static 
    func render(availability:SwiftAvailability?) -> Self?
    {
        guard let availability:SwiftAvailability = availability
        else 
        {
            return nil 
        }
        let adjective:String 
        let toolchain:Self
        if let version:Version = availability.obsoleted 
        {
            adjective = "Obsolete"
            toolchain = .span(version.description) { ("class", "version") }
        } 
        else if let version:Version = availability.deprecated 
        {
            adjective = "Deprecated"
            toolchain = .span(version.description) { ("class", "version") }
        }
        else if let version:Version = availability.introduced
        {
            adjective = "Available"
            toolchain = .span(version.description) { ("class", "version") }
        }
        else 
        {
            return nil
        }
        return .li { "\(adjective, as: .strong) since Swift \(toolchain)" }
    }
    
    static 
    func render(availability:(swift:SwiftAvailability?, general:UnversionedAvailability?)) 
        -> Self?
    {
        var items:[Self] = []
        if  let swift:SwiftAvailability = availability.swift, 
            let item:Self = .render(availability: swift)
        {
            items.append(item)
        }
        if  let general:UnversionedAvailability = availability.general, 
            let item:Self = .render(availability: general)
        {
            items.append(item)
        }
        return items.isEmpty ? nil : .ul(items: items) { ("class", "availability-list") }
    }
    
    static
    func render(availability:[Platform: VersionedAvailability]) -> Self?
    {
        var platforms:[Self] = []
        for platform:Platform in Platform.allCases
        {
            guard let availability:VersionedAvailability = availability[platform]
            else 
            {
                continue 
            }
            if availability.unavailable 
            {
                platforms.append(.li("\(platform.rawValue) unavailable"))
            }
            else if case nil? = availability.deprecated 
            {
                platforms.append(.li("\(platform.rawValue) deprecated"))
            }
            else if case let version?? = availability.deprecated 
            {
                platforms.append(.li("\(platform.rawValue) deprecated since \(version.description)"))
            }
            else if let version:Version = availability.introduced 
            {
                platforms.append(.li("\(platform.rawValue) \(version.description)+"))
            }
        }
        if platforms.isEmpty
        {
            return nil
        }
        else 
        {
            return .section(.ul(items: platforms)) { ("class", "platforms") }
        }
    }
}

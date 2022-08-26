import SymbolGraphs
import Versions
import Notebook
import HTML

extension HTML.Element
{
    static 
    func highlight<Fragments, Link>(_ fragments:Fragments, 
        transform:(Link) throws -> Anchor) 
        rethrows -> [Self]
        where   Fragments:Sequence, 
                Fragments.Element == Notebook<Highlight, Link>.Fragment
    {
        try fragments.map 
        {
            .highlight($0.text, $0.color, href: try $0.link.map(transform))
        }
    }
    static 
    func highlight(escaped string:String, _ color:Highlight, href anchor:Anchor?) 
        -> Self
    {
        self.highlight(.init(escaped: string), color, href: anchor)
    }
    static 
    func highlight(_ string:String, _ color:Highlight, href anchor:Anchor?) 
        -> Self
    {
        self.highlight(.init(string), color, href: anchor)
    }
    static 
    func highlight(_ child:Self, _ color:Highlight, href anchor:Anchor?) 
        -> Self
    {
        if let anchor:Anchor = anchor
        {
            return .a(.highlight(child, color), attributes: [.init(anchor: anchor)])
        }
        else 
        {
            return .highlight(child, color)
        }
    }
}
extension HTML.Element
{
    static 
    func highlight(escaped string:String, _ color:Highlight) -> Self
    {
        Self.highlight(.init(escaped: string), color)
    }
    static 
    func highlight(_ string:String, _ color:Highlight) -> Self
    {
        Self.highlight(.init(string), color)
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
        return .span(child, attributes: [.class(classes)])
    } 
}

extension HTML.Element
{
    static 
    func render<Fragments, Link>(fragments:Fragments, 
        transform:(Link) throws -> Anchor) 
        rethrows -> Self
        where   Fragments:Sequence, 
                Fragments.Element == Notebook<Highlight, Link>.Fragment
    {
        let fragments:[Self] = try Self.highlight(fragments, transform: transform)
        let code:Self = .code(fragments, attributes: [.class("swift")])
        return .section(.pre(code), attributes: [.class("declaration")])
    }
    static 
    func render<Fragments>(signature:Fragments) -> Self
        where   Fragments:Sequence, 
                Fragments.Element == Notebook<Highlight, Never>.Fragment
    {
        return .code(Self.highlight(signature) { (_:Never) -> Anchor in })
    }
}

extension HTML.Element
{
    static 
    func render(path:Path) -> Self
    {
        var components:[Self] = []
            components.reserveCapacity(2 * path.count - 1)
        for component:String in path.prefix
        {
            components.append(.highlight(component, .identifier))
            components.append(.highlight(escaped: ".", .text))
        }
        components.append(.highlight(path.last, .identifier))
        return .code(components)
    }
}
extension HTML.Element
{
    static 
    func render(_ prefix:Self, constraints:[Generic.Constraint<Symbol.Index>], 
        transform:(Symbol.Index) throws -> Anchor) 
        rethrows -> Self?
    {
        guard let ultimate:Generic.Constraint<Symbol.Index> = constraints.last 
        else 
        {
            return nil
        }
        guard let penultimate:Generic.Constraint<Symbol.Index> = 
            constraints.dropLast().last
        else 
        {
            return .p(try [prefix] + Self.render(constraint: ultimate, 
                transform: transform))
        }
        var elements:[Self] = [prefix]
        if constraints.count < 3 
        {
            elements.append(contentsOf: try Self.render(constraint: penultimate, 
                transform: transform))
            elements.append(.init(escaped: " and "))
            elements.append(contentsOf: try Self.render(constraint: ultimate, 
                transform: transform))
        }
        else 
        {
            for constraint:Generic.Constraint<Symbol.Index> in 
                constraints.dropLast(2)
            {
                elements.append(contentsOf: try Self.render(constraint: constraint, 
                    transform: transform))
                elements.append(.init(escaped: ", "))
            }
            elements.append(contentsOf: try Self.render(constraint: penultimate, 
                transform: transform))
            elements.append(.init(escaped: ", and "))
            elements.append(contentsOf: try Self.render(constraint: ultimate, 
                transform: transform))
        }
        return .p(elements)
    }
    static 
    func render(constraint:Generic.Constraint<Symbol.Index>, 
        transform:(Symbol.Index) throws -> Anchor) rethrows -> [Self]
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
        let subject:Self = .code(.highlight(constraint.subject, .type))
        let object:Self = .code(.highlight(constraint.object, .type, 
            href: try constraint.target.map(transform)))
        return [subject, .init(escaped: verb), object]
    }
}

extension HTML.Element
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
        return .li(.strong(escaped: adjective))
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
        if let version:MaskedVersion = availability.obsoleted 
        {
            adjective = "Obsolete"
            toolchain = .span(version.description, attributes: [.class("version")])
        } 
        else if let version:MaskedVersion = availability.deprecated 
        {
            adjective = "Deprecated"
            toolchain = .span(version.description, attributes: [.class("version")])
        }
        else if let version:MaskedVersion = availability.introduced
        {
            adjective = "Available"
            toolchain = .span(version.description, attributes: [.class("version")])
        }
        else 
        {
            return nil
        }
        return .li(.strong(escaped: adjective), 
            .init(escaped: " since Swift "), 
            toolchain)
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
        return items.isEmpty ? nil : .ul(items, attributes: [.class("availability-list")])
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
            else if let deprecated:VersionedAvailability.Deprecation = availability.deprecated 
            {
                switch deprecated 
                {
                case .always:
                    platforms.append(.li("\(platform.rawValue) deprecated"))
                case .since(let version):
                    platforms.append(.li("\(platform.rawValue) deprecated since \(version.description)"))
                }
            }
            else if let version:MaskedVersion = availability.introduced 
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
            return .section(.ul(platforms), attributes: [.class("platforms")])
        }
    }
}

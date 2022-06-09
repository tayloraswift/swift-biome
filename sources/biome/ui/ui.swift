import HTML
import Notebook

extension DOM.Element where Domain == HTML
{
    static 
    func highlight(escaping string:String, _ color:Fragment.Color, href anchor:Anchor?) 
        -> Self
    {
        if let anchor:Anchor = anchor
        {
            return .a(.highlight(escaping: string, .type))
            {
                ("href", .anchor(anchor))
            }
        }
        else 
        {
            return .highlight(escaping: string, .type)
        }
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

extension HTML 
{
    static 
    func render<Fragments>(fragments:Fragments) -> Element<Ecosystem.Index>
        where Fragments:Sequence, Fragments.Element == (String, Fragment.Color, Symbol.Index?)
    {
        Element<Ecosystem.Index>[.section]
        {
            ("class", "declaration")
        }
        content:
        {
            Element<Ecosystem.Index>[.pre]
            {
                Element<Ecosystem.Index>[.code] 
                {
                    ("class", "swift")
                }
                content: 
                {
                    for (text, color, link):(String, Fragment.Color, Symbol.Index?) in fragments 
                    {
                        .highlight(escaping: text, color, 
                            href: link.map(Ecosystem.Index.symbol(_:)))
                    }
                }
            }
        }
    }
}

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
        let object:Element<Ecosystem.Index> =
            .code(.highlight(escaping: constraint.subject, .type, 
                href: constraint.link.map(Ecosystem.Index.symbol(_:))))
        return [subject, .text(escaped: verb), object]
    }
}

extension HTML 
{
    static 
    func render(availability:UnversionedAvailability?) -> Element<Ecosystem.Index>?
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
    static 
    func render(availability:SwiftAvailability?) -> Element<Ecosystem.Index>?
    {
        guard let availability:SwiftAvailability = availability
        else 
        {
            return nil 
        }
        let adjective:String 
        let toolchain:Element<Ecosystem.Index>
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
}

extension HTML 
{
    static
    func render(availability:[Platform: VersionedAvailability]) -> Element<Ecosystem.Index>?
    {
        var platforms:[Element<Ecosystem.Index>] = []
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
            return Element<Ecosystem.Index>[.section]
            {
                ("class", "platforms")
            }
            content: 
            {
                Element<Ecosystem.Index>[.ul]
                {
                    platforms
                }
            }
        }
    }
}

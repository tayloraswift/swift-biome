import Markdown
import HTML

extension Extension 
{
    enum Headline 
    {
        case implicit
        case explicit(Heading)
        
        var rank:Int 
        {
            switch self
            {
            case .implicit: return 1
            case .explicit: return 0
            }
        }
        var level:Int 
        {
            switch self 
            {
            case .implicit:                 return 1 
            case .explicit(let heading):    return heading.level
            }
        }
        
        var plainText:String
        {
            switch self 
            {
            case .implicit:
                return ""
            case .explicit(let headline):
                return headline.plainText
            }
        }
        func rendered<UTF8>(as _:UTF8.Type = UTF8.self) -> UTF8
            where UTF8:RangeReplaceableCollection, UTF8.Element == UInt8
        {
            var output:UTF8 = .init()
            switch self 
            {
            case .implicit:
                break
            case .explicit(let headline):
                for child:any InlineMarkup in headline.inlineChildren
                {
                    HTML.Element<Never>.render(recurring: child).rendered(into: &output)
                }
            }
            return output
        }
    }
}

extension DOM.Element<HTML, Never>
{
    // `RecurringInlineMarkup` is not a useful abstraction
    fileprivate static 
    func render(recurring inline:any InlineMarkup) -> Self
    {
        switch inline
        {
        case is LineBreak:
            return .leaf(.br, attributes: [])
        case is SoftBreak:
            return .text(escaped: " ")
        
        case let span as CustomInline: 
            return .text(escaping: span.text)
        case let text as Text:
            return .text(escaping: text.string)
        case let span as InlineHTML:
            return .text(escaped: span.rawHTML)
        case let span as InlineCode: 
            return .code(span.code)
        case let span as Emphasis:
            return .em(span.inlineChildren.map(Self.render(recurring:)))
        case let span as Strikethrough:
            return .s(span.inlineChildren.map(Self.render(recurring:)))
        case let span as Strong:
            return .strong(span.inlineChildren.map(Self.render(recurring:)))
        case let span as Markdown.Image:
            return .span(span.inlineChildren.map(Self.render(recurring:)))
        case let span as Link:
            return .span(span.inlineChildren.map(Self.render(recurring:)))
        case let link as SymbolLink: 
            return .code(link.destination ?? "")
        default: 
            fatalError("unreachable")
        }
    }
}

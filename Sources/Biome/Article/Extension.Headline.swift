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
                    HTML.Element<Never>.render(recurring: child).node.rendered(into: &output)
                }
            }
            return output
        }
    }
}

extension HTML.Element<Never>
{
    // `RecurringInlineMarkup` is not a useful abstraction
    fileprivate static 
    func render(recurring inline:any InlineMarkup) -> Self
    {
        switch inline
        {
        case is LineBreak:
            return .br
        case is SoftBreak:
            return .init(escaped: " ")
        
        case let span as CustomInline: 
            return .init(span.text)
        case let text as Text:
            return .init(text.string)
        case let span as InlineHTML:
            return .init(escaped: span.rawHTML)
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

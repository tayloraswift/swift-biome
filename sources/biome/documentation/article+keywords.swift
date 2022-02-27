import StructuredDocument
import HTML

extension Biome 
{
    static 
    func keywords(prefixing content:[Frontend]) -> (keywords:[String], trimmed:[Frontend])?
    {
        //  p 
        //  {
        //      text 
        //      {
        //          " foo  bar:  "
        //      }
        //      ...
        //  }
        //  ...
        guard   case .container(.p, id: let id, attributes: let attributes, content: var inline)? = content.first, 
                let first:Frontend = inline.first 
        else 
        {
            return nil
        }
        let keywords:Substring
        switch first 
        {
        case .text(escaped: let string):
            guard let colon:String.Index = string.firstIndex(of: ":")
            else 
            {
                return nil
            }
            let remaining:Substring = string[colon...].dropFirst().drop(while: \.isWhitespace)
            if  remaining.isEmpty 
            {
                inline.removeFirst()
            }
            else 
            {
                inline[0] = .text(escaped: String.init(remaining))
            }
            keywords = string[..<colon]
        
        case .container(let type, id: _, attributes: _, content: let styled):
            switch type 
            {
            case .code, .strong, .em: 
                break 
            default: 
                return nil
            }
            guard   case .text(escaped: let prefix)? = styled.first, styled.count == 1,
                    case .text(escaped: let string)? = inline.dropFirst().first, 
                    let colon:String.Index = string.firstIndex(of: ":"), 
                    string[..<colon].allSatisfy(\.isWhitespace)
            else 
            {
                return nil
            }
            let remaining:Substring = string[colon...].dropFirst().drop(while: \.isWhitespace)
            if  remaining.isEmpty 
            {
                inline.removeFirst(2)
            }
            else 
            {
                inline.removeFirst(1)
                inline[0] = .text(escaped: String.init(remaining))
            }
            keywords = prefix[...]
        default: 
            return nil
        }
        guard let keywords:[String] = Self.keywords(parsing: keywords)
        else 
        {
            return nil
        }
        
        if inline.isEmpty 
        {
            return (keywords, [Frontend].init(content.dropFirst()))
        }
        else 
        {
            var content:[Frontend] = content
                content[0] = .container(.p, id: id, attributes: attributes, content: inline)
            return (keywords, content)
        }

        /* var outer:LazyMapSequence<Markdown.MarkupChildren, Markdown.BlockMarkup>.Iterator = 
           item.blockChildren.makeIterator()
        guard   let paragraph:Markdown.BlockMarkup = outer.next(),
                let paragraph:Markdown.Paragraph = paragraph as? Markdown.Paragraph
        else 
        {
            return nil 
        }
        var inner:LazyMapSequence<Markdown.MarkupChildren, Markdown.InlineMarkup>.Iterator = 
            paragraph.inlineChildren.makeIterator()
        guard let first:Markdown.InlineMarkup = inner.next()
        else 
        {
            return nil 
        }
        let string:String 
        let colon:String.Index
        if  let first:Markdown.Text = first as? Markdown.Text, 
            let index:String.Index  = first.string.firstIndex(of: ":")
        {
            string  = first.string 
            colon   = index 
        }
        // failing example here: https://developer.apple.com/documentation/system/filedescriptor/duplicate(as:retryoninterrupt:)
        // apple docs just drop the parameter
        else if !plain, 
            let first:Markdown.InlineCode = first as? Markdown.InlineCode 
        {
            string  = first.code 
            colon   = string.firstIndex(of: ":") ?? string.endIndex
            print("warning: parameter name '`\(string)`' does not need backticks")
        }
        else 
        {
            return nil 
        }
        let keywords:[String] = string.prefix(upTo: colon)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init(_:))
        let remaining:Substring = string[colon...].dropFirst().drop(while: \.isWhitespace)
        guard remaining.isEmpty 
        else 
        {
            let inline:[Markdown.InlineMarkup] = [Markdown.Text.init(String.init(remaining))] + inner
            let children:[Markdown.BlockMarkup] = [Markdown.Paragraph.init(inline)] + outer
            return (keywords, children)
        }
        if let next:Markdown.InlineMarkup = inner.next()
        {
            let children:[Markdown.BlockMarkup] = [Markdown.Paragraph.init([next] + inner)] + outer
            return (keywords, children)
        }
        else 
        {
            return (keywords, .init(outer))
        } */
    }
    private static 
    func keywords(parsing string:Substring) -> [String]?
    {
        let keywords:[Substring] = string.split(whereSeparator: \.isWhitespace)
        guard 1 ... 8 ~= keywords.count
        else 
        {
            return nil 
        }
        return keywords.map { $0.lowercased() }
    }
}

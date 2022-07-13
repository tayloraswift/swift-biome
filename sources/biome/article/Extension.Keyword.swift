import Markdown

extension ListItem 
{
    func recognize<Keyword>(where keyword:(Substring) throws -> Keyword?) 
        rethrows -> (Keyword, [any BlockMarkup])?
    {
        var blocks:[any BlockMarkup] = .init(self.blockChildren)
        
        guard   let paragraph:any BlockMarkup = blocks.first, 
                let paragraph:Paragraph = paragraph as? Paragraph
        else 
        {
            return nil
        }
        
        let magic:Keyword
        var inline:[any InlineMarkup] = .init(paragraph.inlineChildren)
        // find the first colon among the first two inline elements 
        guard   let first:any InlineMarkup = inline.first
        else 
        {
            return nil 
        }
        if      let text:Text = first as? Text
        {
            // 'keyword: blah blah blah'
            let string:String = text.string 
            guard   let colon:String.Index = string.firstIndex(of: ":"), 
                    let keyword:Keyword = try keyword(string[..<colon])
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
                inline[0] = Text.init(String.init(remaining))
            }
            
            magic = keyword
        }
        else if let second:any InlineMarkup = inline.dropFirst().first, 
                let second:Text = second as? Text
        {
            // '`keyword`: blah blah blah'
            // failing example here: https://developer.apple.com/documentation/system/filedescriptor/duplicate(as:retryoninterrupt:)
            // apple docs just drop the parameter
            let string:Substring = second.string.drop(while: \.isWhitespace) 
            guard   case ":"? = string.first, 
                    let keyword:Keyword = try keyword(first.plainText[...])
            else 
            {
                return nil 
            }
            
            let remaining:Substring = string.dropFirst().drop(while: \.isWhitespace)
            if  remaining.isEmpty  
            {
                inline.removeFirst(2)
            }
            else 
            {
                inline.removeFirst()
                inline[0] = Text.init(String.init(remaining))
            }
            
            magic = keyword
        }
        else 
        {
            return nil
        }
        
        if inline.isEmpty 
        {
            blocks.removeFirst()
        }
        else 
        {
            blocks[0] = Paragraph.init(inline)
        }
        return (magic, blocks)
    }
}

extension Extension 
{
    enum Keyword
    {
        case parameters 
        case parameter(String) 
        case returns
        case aside(Aside)
        case other(String)
        
        init?<S>(_ string:S) where S:StringProtocol, S.SubSequence == Substring
        {
            if let aside:Aside = .init(string)
            {
                self = .aside(aside)
                return
            }
            
            let words:[Substring] = string.split(whereSeparator: \.isWhitespace)
            
            guard let keyword:String = words.first?.lowercased()
            else 
            {
                return nil 
            }
            if words.count == 2 
            {
                if keyword == "parameter"
                {
                    self = .parameter(String.init(words[1]))
                }
                else 
                {
                    return nil 
                }
            }
            else if words.count == 1 
            {
                switch keyword
                {
                case "parameters":      self = .parameters
                case "returns":         self = .returns
                default:                self = .other(String.init(words[0]))
                }
            }
            else 
            {
                return nil
            }
        }
    }
}

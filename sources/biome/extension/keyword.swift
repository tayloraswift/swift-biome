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
        enum Aside:String 
        {
            case attention              = "attention"
            case author                 = "author"
            case authors                = "authors"
            case bug                    = "bug"
            case complexity             = "complexity"
            case copyright              = "copyright"
            case date                   = "date"
            case experiment             = "experiment"
            case important              = "important"
            case invariant              = "invariant"
            case mutatingVariant        = "mutatingvariant"
            case nonMutatingVariant     = "nonmutatingvariant"
            case note                   = "note"
            case postcondition          = "postcondition"
            case precondition           = "precondition"
            case remark                 = "remark"
            case requires               = "requires"
            case seeAlso                = "seealso"
            case since                  = "since"
            case `throws`               = "throws"
            case tip                    = "tip"
            case todo                   = "todo"
            case version                = "version"
            case warning                = "warning"
            
            init(_ markdown:Markdown.Aside.Kind)
            {
                switch markdown 
                {
                    case .attention:            self = .attention
                    case .author:               self = .author
                    case .authors:              self = .authors
                    case .bug:                  self = .bug
                    case .complexity:           self = .complexity
                    case .copyright:            self = .copyright
                    case .date:                 self = .date
                    case .experiment:           self = .experiment
                    case .important:            self = .important
                    case .invariant:            self = .invariant
                    case .mutatingVariant:      self = .mutatingVariant
                    case .nonMutatingVariant:   self = .nonMutatingVariant
                    case .note:                 self = .note
                    case .postcondition:        self = .postcondition
                    case .precondition:         self = .precondition
                    case .remark:               self = .remark
                    case .requires:             self = .requires
                    case .since:                self = .since
                    case .throws:               self = .throws
                    case .tip:                  self = .tip
                    case .todo:                 self = .todo
                    case .version:              self = .version
                    case .warning:              self = .warning
                }
            }
            
            var prose:String 
            {
                switch self 
                {
                    case .attention:            return "Attention"
                    case .author:               return "Author"
                    case .authors:              return "Authors"
                    case .bug:                  return "Bug"
                    case .complexity:           return "Complexity"
                    case .copyright:            return "Copyright"
                    case .date:                 return "Date"
                    case .experiment:           return "Experiment"
                    case .important:            return "Important"
                    case .invariant:            return "Invariant"
                    case .mutatingVariant:      return "Mutating Variant"
                    case .nonMutatingVariant:   return "Non-mutating Variant"
                    case .note:                 return "Note"
                    case .postcondition:        return "Postcondition"
                    case .precondition:         return "Precondition"
                    case .remark:               return "Remark"
                    case .requires:             return "Requires"
                    case .seeAlso:              return "See Also"
                    case .since:                return "Since"
                    case .throws:               return "Throws"
                    case .tip:                  return "Tip"
                    case .todo:                 return "To-do"
                    case .version:              return "Version"
                    case .warning:              return "Warning"
                }
            }
        }
        
        case parameters 
        case parameter(String) 
        case returns
        case aside(Aside)
        case other(String)
        
        init?<S>(_ string:S) where S:StringProtocol, S.SubSequence == Substring
        {
            if let aside:Aside = .init(rawValue: String.init(string.filter(\.isLetter)).lowercased())
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

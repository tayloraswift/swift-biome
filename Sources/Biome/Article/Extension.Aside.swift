import Markdown

extension Extension 
{
    enum Aside
    {
        case attention
        case author
        case authors
        case bug
        case complexity
        case copyright
        case date
        case experiment
        case important
        case invariant
        case mutatingVariant
        case nonMutatingVariant
        case note
        case postcondition
        case precondition
        case remark
        case requires
        case seeAlso
        case since
        case `throws`
        case tip
        case todo
        case version
        case warning
        
        case other(String)
        
        // will *not* detect `other(_:)`
        init?<S>(_ string:S) where S:StringProtocol 
        {
            switch String.init(string.filter(\.isLetter)).lowercased() 
            {
            case "attention":           self = .attention
            case "author":              self = .author
            case "authors":             self = .authors
            case "bug":                 self = .bug
            case "complexity":          self = .complexity
            case "copyright":           self = .copyright
            case "date":                self = .date
            case "experiment":          self = .experiment
            case "important":           self = .important
            case "invariant":           self = .invariant
            case "mutatingvariant":     self = .mutatingVariant
            case "nonmutatingvariant":  self = .nonMutatingVariant
            case "note":                self = .note
            case "postcondition":       self = .postcondition
            case "precondition":        self = .precondition
            case "remark":              self = .remark
            case "requires":            self = .requires
            case "seealso":             self = .seeAlso
            case "since":               self = .since
            case "throws":              self = .throws
            case "tip":                 self = .tip
            case "todo":                self = .todo
            case "version":             self = .version
            case "warning":             self = .warning
            default:                    return nil
            //default:                    self = .other(String.init(string))
            }
        }
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
                
                default:                    self = .other(markdown.rawValue)
            }
        }
        
        var `class`:String 
        {
            switch self 
            {
            case .attention:            return "attention"
            case .author:               return "author"
            case .authors:              return "authors"
            case .bug:                  return "bug"
            case .complexity:           return "complexity"
            case .copyright:            return "copyright"
            case .date:                 return "date"
            case .experiment:           return "experiment"
            case .important:            return "important"
            case .invariant:            return "invariant"
            case .mutatingVariant:      return "mutatingvariant"
            case .nonMutatingVariant:   return "nonmutatingvariant"
            case .note:                 return "note"
            case .postcondition:        return "postcondition"
            case .precondition:         return "precondition"
            case .remark:               return "remark"
            case .requires:             return "requires"
            case .seeAlso:              return "seealso"
            case .since:                return "since"
            case .throws:               return "throws"
            case .tip:                  return "tip"
            case .todo:                 return "todo"
            case .version:              return "version"
            case .warning:              return "warning"
            case .other(_):             return "other"
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
                
                case .other(let other):     return other 
            }
        }
    }
}

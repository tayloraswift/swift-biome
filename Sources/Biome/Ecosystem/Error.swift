extension Ecosystem 
{
    struct LinkResolutionError:Error 
    {
        let link:String
        let error:Error
    }
}
extension Packages 
{
    enum SelectionError:Error 
    {
        case none 
        case many([Symbol.Composite])
    }
    enum DependencyError:Error 
    {
        case packageNotFound(Package.ID)
        case targetNotFound(Module.ID, in:Package.ID)
    }
    enum PoliticalError:Error, CustomStringConvertible
    {
        case module(Module.ID, says:Symbol.ID, is:Symbol.Role<Symbol.ID>)
        case symbol(Symbol.ID, Symbol.PoliticalError<Symbol.ID>)
        
        public 
        var description:String 
        {
            switch self 
            {
            case .module(let culture, says: let subject, is: let role):
                return "module '\(culture)' says \(subject) is \(role)"
            case .symbol(let subject, let predicate):
                return "symbol '\(subject)' \(predicate)"
            }
        }
    }
}
extension Module 
{
    public 
    enum SubgraphDecodingError:Error, CustomStringConvertible 
    {
        case duplicateAvailabilityDomain(Availability.Domain)
        case invalidFragmentColor(String)
        case mismatchedCulture(ID, expected:ID)
        
        public 
        var description:String 
        {
            switch self 
            {
            case .duplicateAvailabilityDomain(let domain):
                return "duplicate entries for availability domain '\(domain.rawValue)'"
            case .mismatchedCulture(let id, expected: let expected): 
                return "subgraph culture is '\(id)', expected '\(expected)'"
            case .invalidFragmentColor(let string): 
                return "invalid fragment color '\(string)'"
            }
        }
    }
}
extension Symbol 
{
    public 
    enum PoliticalError<Target>:Error, CustomStringConvertible 
    {
        case miscegenation(is:Color, and:Edge.Kind?, of:(adjective:Color, noun:Target))
        case conflict(is:Role<Target>, and:Role<Target>)
        
        func map<T>(_ transform:(Target) throws -> T) rethrows -> PoliticalError<T>
        {
            switch self 
            {
            case .conflict(is: let first, and: let second):
                return .conflict(is: try first.map(transform), 
                    and: try second.map(transform))
            case .miscegenation(is: let color, and: let relation, of: let object):
                return .miscegenation(is: color, and: relation, 
                    of: (object.adjective, try transform(object.noun)))
            }
        }
        public 
        var description:String 
        {
            switch self 
            {
            case .conflict(is: let first, and: let second):
                return "is \(first) and \(second)"
            case .miscegenation(is: let color, and: let relation, of: let object):
                return "is \(color) and \(relation?.description ?? "feature") of \(object.adjective) '\(object.noun)'"
            }
        }
    }
    public 
    enum LookupError:Error, CustomStringConvertible
    {
        case unknownID(ID)
        
        public 
        var description:String 
        {
            switch self 
            {
            case .unknownID(let id):
                return "could not find symbol with id '\(id)'"
            }
        }
    }
}

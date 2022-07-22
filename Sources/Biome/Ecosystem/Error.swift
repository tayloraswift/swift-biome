import SymbolGraphs

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
extension Symbol 
{
    public 
    enum PoliticalError<Target>:Error, CustomStringConvertible 
    {
        case miscegenation(is:Community, and:Edge.Kind?, of:(adjective:Community, noun:Target))
        case conflict(is:Role<Target>, and:Role<Target>)
        
        func map<T>(_ transform:(Target) throws -> T) rethrows -> PoliticalError<T>
        {
            switch self 
            {
            case .conflict(is: let first, and: let second):
                return .conflict(is: try first.map(transform), 
                    and: try second.map(transform))
            case .miscegenation(is: let community, and: let relation, of: let object):
                return .miscegenation(is: community, and: relation, 
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
            case .miscegenation(is: let community, and: let relation, of: let object):
                return "is \(community) and \(relation?.description ?? "feature") of \(object.adjective) '\(object.noun)'"
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

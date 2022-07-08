extension Ecosystem 
{
    public 
    enum DependencyError:Error 
    {
        case packageNotFound(Package.ID)
        case targetNotFound(Module.ID, in:Package.ID)
    }
    public 
    enum AuthorityError:Error
    {
        case externalSymbol(Symbol.Index, is:Symbol.Role, accordingTo:Module.Index)
    }
    public 
    struct LinkResolutionError:Error 
    {
        let link:String
        let error:Error
    }
    public 
    enum SelectionError:Error 
    {
        case none 
        case many([Symbol.Composite])
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
    enum ColorError:Error 
    {
        case miscegenation(Color, is:Edge.Kind?, of:Color)
    }
    public 
    enum ShapeError:Error 
    {
        case conflict   (is:Shape, and:Shape)
        case subclass   (of:Index, and:Index)
        case requirement(of:Index, is:Role)
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
                return "could not find symbol with id '\(id.string)' (\(id.description))"
            }
        }
    }
}

import SymbolGraphs

enum DependencyError:Error 
{
    case packageNotFound(Package.ID)
    case moduleNotFound(Module.ID, in:Package.ID)

    case packageCycle
    case moduleCycle(in:Package.ID)
}

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
}
extension Symbol 
{
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

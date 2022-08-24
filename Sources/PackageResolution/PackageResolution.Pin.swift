import SymbolGraphs
import Versions 
import JSON

extension PackageResolution
{
    public 
    struct Pin:Identifiable 
    {
        public 
        struct State 
        {
            let requirement:Requirement 
            let revision:String
            
            public 
            init(_ requirement:Requirement, revision:String)
            {
                self.requirement = requirement 
                self.revision = revision
            }
        }
        public 
        enum Requirement 
        {
            case version(MaskedVersion)
            case branch(String)
        }
        
        public 
        let id:PackageIdentifier
        public
        let state:State 
        let location:String?
        
        public 
        init(from json:JSON) throws 
        {
            (self.id, self.state, self.location) = try json.lint(whitelisting: ["kind"])
            {
                let id:ID = .init(
                    try $0.pop("identity", as: String.self) ?? 
                        $0.remove("package", as: String.self))
                let location:String? = try $0.pop("location", as: String.self) ?? 
                    $0.pop("repositoryURL", as: String.self)
                let state:State = try $0.remove("state")
                {
                    try $0.lint(whitelisting: ["branch"]) 
                    {
                        let revision:String = try $0.remove("revision", as: String.self)
                        let requirement:Requirement
                        if let version:String = try $0.pop("version", as: String?.self)
                        {
                            requirement = .version(try .init(parsing: version))
                        }
                        else 
                        {
                            requirement = .branch(try $0.remove("branch", as: String.self))
                        }
                        return .init(requirement, revision: revision)
                    }
                }
                return (id, state, location)
            }
        }
    }
}

import JSON

extension Package 
{
    public 
    enum Version:CustomStringConvertible, Sendable
    {
        case date(year:Int, month:Int, day:Int)
        case tag(major:Int, (minor:Int, (patch:Int, edition:Int?)?)?)
        
        public 
        var description:String 
        {
            switch self
            {
            case .date(year: let year, month: let month, day: let day):
                // not zero-padded, and probably unsuitable for generating 
                // links to toolchains.
                return "\(year)-\(month)-\(day)"
            case .tag(major: let major, nil):
                return "\(major)"
            case .tag(major: let major, (minor: let minor, nil)?):
                return "\(major).\(minor)"
            case .tag(major: let major, (minor: let minor, (patch: let patch, edition: nil)?)?):
                return "\(major).\(minor).\(patch)"
            case .tag(major: let major, (minor: let minor, (patch: let patch, edition: let edition?)?)?):
                return "\(major).\(minor).\(patch).\(edition)"
            }
        }
    }
}
extension Package.Version 
{
    init(from json:JSON) throws 
    {
        self = try json.lint 
        {
            let major:Int = try $0.remove("major", as: Int.self)
            guard let minor:Int = try $0.pop("minor", as: Int.self)
            else 
            {
                return .tag(major: major, nil)
            }
            guard let patch:Int = try $0.pop("patch", as: Int.self)
            else 
            {
                return .tag(major: major, (minor, nil))
            }
            return .tag(major: major, (minor, (patch, nil)))
        }
    }
}

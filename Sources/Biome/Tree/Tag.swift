import PackageResolution

public
enum Tag:Hashable, Sendable 
{
    public 
    enum Semantic:Hashable, Sendable
    {
        case major(UInt16)
        case minor(UInt16, UInt16)
        case patch(UInt16, UInt16, UInt16)
    }

    case semantic(Semantic)
    case named(String)

    init?(parsing string:some StringProtocol) 
    {
        if string.isEmpty 
        {
            return nil 
        }
        if let semantic:Semantic = try? .init(parsing: string)
        {
            self = .semantic(semantic)
            return 
        }
        guard   string != ".",
                string != ".."
        else 
        {
            return nil
        }
        // a tag name must not contain a slash '/' (which is legal in git)
        for character:Character in string where character == "/"
        {
            return nil 
        }
        self = .named(String.init(string))
    }

    init?(_ requirement:PackageResolution.Requirement)
    {
        switch requirement 
        {
        case .version(let version): 
            self = .semantic(.patch(
                .init(version.major), 
                .init(version.minor), 
                .init(version.patch)))
        case .branch(let name): 
            self.init(parsing: name)
        }
    }
}
extension Tag.Semantic:CustomStringConvertible 
{
    public 
    var description:String
    {
        switch self 
        {
        case .major(let major): 
            return "\(major)"
        case .minor(let major, let minor):
            return "\(major).\(minor)"
        case .patch(let major, let minor, let patch):
            return "\(major).\(minor).\(patch)"
        }
    }
}
extension Tag:CustomStringConvertible 
{
    public 
    var description:String
    {
        switch self 
        {
        case .semantic(let version): 
            return version.description
        case .named(let name):
            return name
        }
    }
}
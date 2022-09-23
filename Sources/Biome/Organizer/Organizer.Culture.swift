import HTML 

extension Organizer 
{
    enum Culture
    {
        case primary 
        case accepted(ModuleReference)
        case nonaccepted(ModuleReference, PackageReference)
    }
}
extension Organizer.Culture 
{
    enum SortingKey:Comparable 
    {
        case primary 
        case accepted(Module.ID)
        case nonaccepted(Package.ID, Module.ID)
    }

    var sortingKey:SortingKey
    {
        switch self 
        {
        case .primary: 
            return .primary
        case .accepted(let culture): 
            return .accepted(culture.name)
        case .nonaccepted(let culture, let nationality): 
            return .nonaccepted(nationality.name, culture.name)
        }
    }
}

extension Organizer.Culture 
{
    var html:[HTML.Element<Never>]?
    {
        switch self 
        {
        case .primary: 
            return nil 
        case .accepted(let culture):
            return [culture.html]
        case .nonaccepted(let culture, let nationality):
            return [culture.html, nationality.html]
        }
    }
}
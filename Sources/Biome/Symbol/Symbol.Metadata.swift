extension Symbol 
{
    enum Metadata:Equatable, Sendable
    {
        case missing 
        case present(
            roles:Roles<Branch.Position<Symbol>>?,
            primary:Traits<Branch.Position<Symbol>>,
            accepted:[Branch.Position<Module>: Traits<Branch.Position<Symbol>>])
    }
}
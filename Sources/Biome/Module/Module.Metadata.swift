extension Module 
{
    enum Metadata:Equatable, Sendable 
    {
        case missing 
        case present(dependencies:Set<Branch.Position<Module>>)
    }
}
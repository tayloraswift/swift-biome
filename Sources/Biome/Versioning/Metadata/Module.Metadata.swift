extension Module
{
    struct Metadata:Equatable, Sendable 
    {
        let dependencies:Set<Atom<Module>>

        init(dependencies:Set<Atom<Module>>)
        {
            self.dependencies = dependencies
        }
    }
}
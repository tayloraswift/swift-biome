extension Compound 
{
    struct Position 
    {
        let atoms:Compound 
        private 
        let branches:
        (
            base:Version.Branch, 
            host:Version.Branch, 
            culture:Version.Branch
        )

        init(_ atoms:Compound,
            culture:Version.Branch, 
            host:Version.Branch, 
            base:Version.Branch)
        {
            self.branches.culture = culture
            self.branches.host = host
            self.branches.base = base
            self.atoms = atoms 
        }
    }
}
extension Compound.Position 
{
    var nationality:Package.Index
    {
        self.atoms.culture.nationality
    }
    var culture:Atom<Module>.Position
    {
        .init(self.atoms.culture, branch: self.branches.culture)
    }
    var host:Atom<Symbol>.Position
    {
        .init(self.atoms.host, branch: self.branches.host)
    }
    var base:Atom<Symbol>.Position
    {
        .init(self.atoms.base, branch: self.branches.base)
    }
}
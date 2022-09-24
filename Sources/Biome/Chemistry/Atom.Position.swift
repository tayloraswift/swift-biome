extension Atom 
{
    struct Position:Hashable where Element:BranchElement
    {
        let atom:Atom<Element>
        let branch:Version.Branch 

        init(_ atom:Atom<Element>, branch:Version.Branch)
        {
            self.atom = atom
            self.branch = branch
        }

        var culture:Element.Culture 
        {
            self.atom.culture
        }
    }
}

extension Atom.Position:Sendable where Element.Offset:Sendable, Element.Culture:Sendable
{
}

extension Atom.Position where Element.Culture == Atom<Module>
{
    var nationality:Package.Index 
    {
        self.atom.nationality
    }
}
extension Atom<Module>.Position
{
    var nationality:Package.Index 
    {
        self.atom.nationality
    }
}

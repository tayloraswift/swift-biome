import Versions 

extension Branch 
{
    struct Ring:Sendable 
    {
        let modules:Module.Offset
        let symbols:Symbol.Offset
        let articles:Article.Offset
    }
    struct Revision:Sendable 
    {
        let token:UInt 
        
        var alternates:[Version.Branch]
        var consumers:[Packages.Index: [Version: Set<Atom<Module>>]]
        let commit:Commit
        let ring:Ring
        let pins:[Packages.Index: Version]

        init(commit:Commit, token:UInt, ring:Ring, pins:[Packages.Index: Version])
        {

            self.alternates = []
            self.consumers = [:]
            self.commit = commit
            self.token = token 
            self.ring = ring 
            self.pins = pins 
        }

        var date:Date
        {
            self.commit.date
        }
        var tag:Tag?
        {
            self.commit.tag
        }
    }
}
extension Branch.Revision 
{
    mutating 
    func branch(_ branch:Version.Branch) -> Branch.Ring 
    {
        self.alternates.append(branch)
        return self.ring 
    }
}
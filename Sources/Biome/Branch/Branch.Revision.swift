extension Branch 
{
    struct Ring:Sendable 
    {
        //let revision:Int 
        let modules:Module.Offset
        let symbols:Symbol.Offset
        let articles:Article.Offset
    }
    struct Revision:Sendable 
    {
        let token:UInt 
        
        var alternates:[Version.Branch]
        var consumers:[Packages.Index: [Version: Set<Atom<Module>>]]
        let hash:String
        let ring:Ring
        let pins:[Packages.Index: Version]
        let date:Date
        var tag:Tag? 

        var version:PreciseVersion 
        {
            fatalError("obsoleted")
        }

        init(token:UInt, hash:String, ring:Ring, pins:[Packages.Index: Version], date:Date, tag:Tag?)
        {
            self.token = token 

            self.alternates = []
            self.consumers = [:]
            self.hash = hash 
            self.ring = ring 
            self.pins = pins 
            self.date = date 
            self.tag = tag 
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
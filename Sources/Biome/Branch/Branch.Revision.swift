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
        var consumers:[Package.Index: Set<_Version>]

        let hash:String
        let ring:Ring
        let pins:[Package.Index: _Version]
        let date:Date
        var tag:Tag? 

        var version:PreciseVersion 
        {
            fatalError("obsoleted")
        }

        init(hash:String, ring:Ring, pins:[Package.Index: _Version], date:Date, tag:Tag?)
        {
            self.consumers = [:]
            self.hash = hash 
            self.ring = ring 
            self.pins = pins 
            self.date = date 
            self.tag = tag 
        }
    }
}
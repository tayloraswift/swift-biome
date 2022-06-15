import Grammar

struct Link:Hashable, Sendable
{
    let target:Ecosystem.Index 
    let visible:Int
    
    init(_ target:Ecosystem.Index, visible:Int)
    {
        self.target = target 
        self.visible = visible
    }
}
extension Link 
{
    struct Disambiguator 
    {
        let host:Symbol.ID?
        let base:Symbol.ID?
        let suffix:Suffix?
    }
}

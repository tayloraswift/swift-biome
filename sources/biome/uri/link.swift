import Grammar

enum Link:Hashable, Sendable
{
    case resolved(Ecosystem.Index, visible:Int)
    case unresolved(String)
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

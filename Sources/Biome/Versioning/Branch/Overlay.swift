struct Overlay:BranchDivergence
{
    typealias Key = Diacritic

    // isomorphic to ``Never``, its fields are only defined so that 
    // keypaths can be constructed to them.
    struct Base:BranchDivergenceBase
    {
        var metadata:OriginalHead<Metadata?>?
        {
            get { nil }
            set {     }
        }
    }

    var metadata:AlternateHead<Metadata?>?

    init() 
    {
        self.metadata = nil
    }

    var isEmpty:Bool
    {
        if case nil = self.metadata
        {
            return true
        }
        else 
        {
            return false
        }
    }
}
// isomorphic to ``Never``, its fields are only defined so that 
// keypaths can be constructed to them.
enum Overlay
{
    var metadata:OriginalHead<Metadata?>?
    {
        get { nil }
        set {     }
    }
}
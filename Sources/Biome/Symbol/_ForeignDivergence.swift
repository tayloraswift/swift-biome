typealias _ForeignMetadata = Symbol.Traits<Branch.Position<Symbol>>

struct _ForeignDivergence:Voidable
{
    var metadata:_History<_ForeignMetadata>.Divergent?

    init() 
    {
        self.metadata = nil
    }
}
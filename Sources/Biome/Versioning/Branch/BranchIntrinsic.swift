protocol BranchIntrinsicBase:BranchDivergenceBase
{
    init()
}
protocol BranchIntrinsic:Intrinsic, Identifiable
{
    associatedtype Divergence:BranchDivergence 
        where Divergence.Key == Atom<Self>, Divergence.Base:BranchIntrinsicBase
}
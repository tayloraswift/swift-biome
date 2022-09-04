public 
protocol BranchElement<Culture, Offset>:Identifiable
{
    associatedtype Culture:Hashable 
    associatedtype Offset:UnsignedInteger
    associatedtype Divergence
}
extension BranchElement
{
    public 
    typealias Index = Branch.Position<Self>
}

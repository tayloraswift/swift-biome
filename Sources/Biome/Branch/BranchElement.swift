public 
protocol BranchElement<Culture, Offset>:Identifiable
{
    associatedtype Culture:Hashable 
    associatedtype Offset:UnsignedInteger
    associatedtype _Heads
}
extension BranchElement
{
    public 
    typealias Index = Branch.Position<Self>
}

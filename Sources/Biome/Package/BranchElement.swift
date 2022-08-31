public 
protocol BranchElement<Culture, Offset>:Identifiable
{
    associatedtype Culture:Hashable 
    associatedtype Offset:UnsignedInteger
}
extension BranchElement
{
    public 
    typealias Index = Branch.Buffer<Self>.OpaqueIndex
}

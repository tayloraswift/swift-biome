public 
protocol AtomicElement<Culture, Offset>:Identifiable
{
    associatedtype Offset:UnsignedInteger where Offset.Stride == Int
    associatedtype Culture:Hashable 
}

protocol BranchElement<Divergence>
{
    associatedtype Divergence:Voidable
}
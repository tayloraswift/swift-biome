public 
protocol BranchElement<Culture, Offset>:Identifiable
{
    associatedtype Offset:UnsignedInteger where Offset.Stride == Int
    associatedtype Culture:Hashable 
    associatedtype Divergence
}
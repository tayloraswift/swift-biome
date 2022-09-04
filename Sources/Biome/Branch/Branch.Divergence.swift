import Forest 

extension Branch 
{
    typealias Head<Value> = Forest<_History<Value>.Keyframe>.Tree.Head where Value:Equatable

    struct Divergence<Value> where Value:Equatable
    {
        var head:Forest<_History<Value>.Keyframe>.Tree.Head
        /// The first revision in which this field diverged from its parent branch.
        var start:_Version.Revision
    }
}
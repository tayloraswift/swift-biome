// @usableFromInline
// struct Version:Hashable, Strideable, Sendable
// {
//     let offset:Int 
    
//     static 
//     let max:Self = .init(offset: .max)
    
//     @usableFromInline static 
//     func < (lhs:Self, rhs:Self) -> Bool 
//     {
//         lhs.offset < rhs.offset 
//     }
//     @usableFromInline
//     func advanced(by offset:Int) -> Self
//     {
//         .init(offset: self.offset.advanced(by: offset))
//     }
//     @usableFromInline
//     func distance(to other:Self) -> Int
//     {
//         self.offset.distance(to: other.offset)
//     }

//     var _predecessor:Self 
//     {
//         self.advanced(by: -1)
//     }
// }

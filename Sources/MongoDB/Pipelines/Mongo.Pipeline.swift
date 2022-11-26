// import BSONDecoding
// import NIOCore

// extension Mongo
// {
//     @frozen public
//     struct Pipeline:Sendable
//     {
//         public
//         var stages:[Document]

//         @inlinable public
//         init(stages:[Document])
//         {
//             self.stages = stages
//         }
//     }
// }
// extension Mongo.Pipeline:BSONArrayDecodable
// {
//     @inlinable public
//     init(bson:BSON.Array<ByteBufferView>) throws
//     {
//         self.init(stages: try bson.map
//         {
//             .init([UInt8].init(
//                 try $0.decode(to: BSON.Document<ByteBufferView>.self).bytes))
//         })
//     }
// }
// extension Mongo.Pipeline
// {
//     public
//     var bson:BSON.Tuple<[UInt8]>
//     {
//         .init(self.stages.lazy.map(BSON.Value<[UInt8]>.document(_:)))
//     }
// }

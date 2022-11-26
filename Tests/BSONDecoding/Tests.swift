import Testing
import BSONDecoding

extension Tests
{
    mutating
    func test<Failure, Unexpected>(name:String, decoding bson:BSON.Document<[UInt8]>, 
        failure:Failure,
        decoder decode:(BSON.Dictionary<ArraySlice<UInt8>>) throws -> Unexpected)
        where Failure:Equatable & Error
    {
        self.do(name: name, expecting: failure)
        {
            _ in _ = try decode(try .init(fields: try bson.parse()))
        }
    }
    mutating
    func test<Decoded>(name:String, decoding bson:BSON.Document<[UInt8]>,
        expecting expected:Decoded,
        decoder decode:(BSON.Dictionary<ArraySlice<UInt8>>) throws -> Decoded)
        where Decoded:Equatable
    {
        self.do(name: name)
        {
            let decoded:Decoded = try decode(try .init(fields: try bson.parse()))
            $0.assert(expected ==? decoded, name: "value")
        }
    }
}

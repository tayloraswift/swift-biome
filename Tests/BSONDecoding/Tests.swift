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
    func test<Expected>(name:String, decoding bson:BSON.Document<[UInt8]>,
        expecting expected:Expected,
        decoder decode:(BSON.Dictionary<ArraySlice<UInt8>>) throws -> Expected)
        where Expected:Equatable
    {
        self.do(name: name)
        {
            let decoded:Expected = try decode(try .init(fields: try bson.parse()))
            $0.assert(expected == decoded, name: "\(name).value")
        }
    }
}

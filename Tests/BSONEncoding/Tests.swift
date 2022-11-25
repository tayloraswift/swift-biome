import Testing
import BSONEncoding

extension Tests
{
    mutating
    func test(name:String,
        encoded:BSON.Document<[UInt8]>,
        literal:BSON.Document<[UInt8]>)
    {
        self.assert(encoded ==? literal, name: name)
    }
}

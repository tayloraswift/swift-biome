import Testing
import Base16
import _BSON

@main 
struct Main:UnitTests
{
    var passed:Int 
    var failed:[any Error]

    init() 
    {
        self.passed = 0
        self.failed = []
    }

    static 
    func main() 
    {
        var main:Self = .init()

        // https://github.com/mongodb/specifications/blob/master/source/bson-corpus/tests/array.json
        try? main.test(
            canonical: "0D000000046100050000000000", 
            expected: ["a": []])
        
        try? main.test(
            canonical: "140000000461000C0000001030000A0000000000", 
            expected: ["a": [.int32(10)]])
        
        try? main.test(
            degenerate: "130000000461000B00000010000A0000000000", 
            canonical: "140000000461000C0000001030000A0000000000", 
            expected: ["a": [.int32(10)]])
        
        try? main.test(
            degenerate: "150000000461000D000000106162000A0000000000", 
            canonical: "140000000461000C0000001030000A0000000000", 
            expected: ["a": [.int32(10)]])
        
        try? main.test(
            degenerate: "1b000000046100130000001030000a000000103000140000000000", 
            canonical: "1b000000046100130000001030000a000000103100140000000000", 
            expected: ["a": [.int32(10), .int32(20)]])
        
        try? main.test(invalid: "140000000461000D0000001030000A0000000000",
            failure: BSON.EndOfInputError.unexpected)
        try? main.test(invalid: "140000000461000B0000001030000A0000000000",
            failure: BSON.EndOfInputError.expected(encountered: 1))
        try? main.test(invalid: "1A00000004666F6F00100000000230000500000062617A000000",
            failure: BSON.EndOfInputError.unexpected)
        
        // https://github.com/mongodb/specifications/blob/master/source/bson-corpus/tests/binary.json
        try? main.test(
            canonical: "0D000000057800000000000000",
            expected: ["x": .binary(.init(subtype: .generic, bytes: []))])
        
        try? main.test(
            canonical: "0F0000000578000200000000FFFF00",
            expected: ["x": .binary(.init(subtype: .generic,
                bytes: Base16.decode(utf8: "ffff".utf8)!))])
        
        try? main.test(
            canonical: "0F0000000578000200000001FFFF00",
            expected: ["x": .binary(.init(subtype: .function,
                bytes: Base16.decode(utf8: "ffff".utf8)!))])
        
        try? main.test(
            canonical: "1D000000057800100000000473FFD26444B34C6990E8E7D1DFC035D400", 
            expected: ["x": .binary(.init(subtype: .uuid,
                bytes: Base16.decode(utf8: "73ffd26444b34c6990e8e7d1dfc035d4".utf8)!))])
        
        try? main.test(
            canonical: "1D000000057800100000000573FFD26444B34C6990E8E7D1DFC035D400", 
            expected: ["x": .binary(.init(subtype: .md5,
                bytes: Base16.decode(utf8: "73ffd26444b34c6990e8e7d1dfc035d4".utf8)!))])
        
        try? main.test(
            canonical: "1D000000057800100000000773FFD26444B34C6990E8E7D1DFC035D400", 
            expected: ["x": .binary(.init(subtype: .compressed,
                bytes: Base16.decode(utf8: "73ffd26444b34c6990e8e7d1dfc035d4".utf8)!))])
        
        try? main.test(
            canonical: "0F0000000578000200000080FFFF00",
            expected: ["x": .binary(.init(subtype: .custom(code: 0x80),
                bytes: Base16.decode(utf8: "ffff".utf8)!))])
        
        try? main.test(invalid: "1D000000057800FF0000000573FFD26444B34C6990E8E7D1DFC035D400",
            failure: BSON.EndOfInputError.unexpected)
        try? main.test(invalid: "0D000000057800FFFFFFFF0000",
            failure: BSON.BinarySubtypeError.missing)
        // TODO: tests for legacy binary subtype 0x02

        // https://github.com/mongodb/specifications/blob/master/source/bson-corpus/tests/boolean.json
        try? main.test(
            canonical: "090000000862000100",
            expected: ["b": true])
        try? main.test(
            canonical: "090000000862000000",
            expected: ["b": false])
        
        try? main.test(invalid: "090000000862000200",
            failure: BSON.BooleanSubtypeError.invalid(2))
        try? main.test(invalid: "09000000086200FF00",
            failure: BSON.BooleanSubtypeError.invalid(255))
        
        main.summarize()
    }
}
extension Main
{
    mutating
    func test<Failure>(invalid:String, failure:Failure) throws where Failure:Error & Equatable
    {
        let invalid:[UInt8] = try self.unwrap(Base16.decode(utf8: invalid.utf8,
            as: [UInt8].self))
        let document:BSON.Document<ArraySlice<UInt8>> = .init(
            slicing: invalid.dropFirst(4))
        
        self.assert(failure: failure)
        {
            print(try document.canonicalized())
        }
    }
    mutating
    func test(degenerate:String? = nil, canonical:String, 
        expected:BSON.Document<[UInt8]>) throws
    {
        let canonical:[UInt8] = try self.unwrap(Base16.decode(utf8: canonical.utf8,
            as: [UInt8].self))
        let size:Int32 = canonical.prefix(4).withUnsafeBytes
        {
            .init(littleEndian: $0.load(as: Int32.self))
        }

        let document:BSON.Document<ArraySlice<UInt8>> = .init(
            slicing: canonical.dropFirst(4))

        self.assert(canonical.count ==? .init(size))
        self.assert(document.header ==? size)


        self.assert(expected ~~ document)
        self.assert(expected == document)

        if  let degenerate:String
        {
            let degenerate:[UInt8] = try self.unwrap(Base16.decode(utf8: degenerate.utf8,
                as: [UInt8].self))
            let document:BSON.Document<ArraySlice<UInt8>> = .init(
                slicing: degenerate.dropFirst(4))
            let canonicalized:BSON.Document<ArraySlice<UInt8>> = 
                try self.unwrap(try? document.canonicalized())
            
            self.assert(expected ~~ document)
            self.assert(expected == canonicalized)
        }
    }
}

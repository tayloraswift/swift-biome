import Testing
import BSONDecoding

@main 
enum Main
{
    static
    func main() throws
    {
        var tests:UnitTests = .init()

        tests.group("numeric")
        {
            let bson:BSON.Document<[UInt8]> =
            [
                "int32": .int32(0x7fff_ffff),
                "int64": .int64(0x7fff_ffff_ffff_ffff),
                "uint64": .uint64(0x7fff_ffff_ffff_ffff),
            ]

            $0.test(name: "int32-to-uint8", decoding: bson,
                failure: BSON.RecursiveError<String>.init(
                    BSON.IntegerOverflowError<UInt8>.int32(0x7fff_ffff),
                    in: "int32"))
            {
                try $0["int32"].decode(to: UInt8.self)
            }

            $0.test(name: "int32-to-int32", decoding: bson,
                expecting: 0x7fff_ffff)
            {
                try $0["int32"].decode(to: Int32.self)
            }

            $0.test(name: "int32-to-int", decoding: bson,
                expecting: 0x7fff_ffff)
            {
                try $0["int32"].decode(to: Int.self)
            }

            $0.test(name: "int64-to-int", decoding: bson,
                expecting: 0x7fff_ffff_ffff_ffff)
            {
                try $0["int64"].decode(to: Int.self)
            }
            $0.test(name: "uint64-to-int", decoding: bson,
                expecting: 0x7fff_ffff_ffff_ffff)
            {
                try $0["uint64"].decode(to: Int.self)
            }
        }

        tests.group("tuple")
        {
            let bson:BSON.Document<[UInt8]> =
            [
                "none":     [],
                "two":      ["a", "b"],
                "three":    ["a", "b", "c"],
                "four":     ["a", "b", "c", "d"],

                "heterogenous": ["a", "b", 0, "d"],
            ]

            $0.test(name: "none-to-two", decoding: bson,
                failure: BSON.RecursiveError<String>.init(
                    BSON.ArrayShapeError.init(count: 0, expected: 2),
                    in: "none"))
            {
                try $0["none"].decode
                {
                    try $0.as(BSON.Array<ArraySlice<UInt8>>.self, count: 2)
                }
            }

            $0.test(name: "two-to-two", decoding: bson,
                expecting: ["a", "b"])
            {
                try $0["two"].decode
                {
                    try $0.as(BSON.Array<ArraySlice<UInt8>>.self, count: 2).elements
                }
            }

            $0.test(name: "three-to-two", decoding: bson,
                failure: BSON.RecursiveError<String>.init(
                    BSON.ArrayShapeError.init(count: 3, expected: 2),
                    in: "three"))
            {
                try $0["three"].decode
                {
                    try $0.as(BSON.Array<ArraySlice<UInt8>>.self, count: 2)
                }
            }

            $0.test(name: "three-by-two", decoding: bson,
                failure: BSON.RecursiveError<String>.init(
                    BSON.ArrayShapeError.init(count: 3, expected: nil),
                    in: "three"))
            {
                try $0["three"].decode
                {
                    try $0.as(BSON.Array<ArraySlice<UInt8>>.self) { $0.isMultiple(of: 2) }
                }
            }

            $0.test(name: "four-by-two", decoding: bson,
                expecting: ["a", "b", "c", "d"])
            {
                try $0["four"].decode
                {
                    (try $0.as(BSON.Array<ArraySlice<UInt8>>.self) { $0.isMultiple(of: 2) })
                        .elements
                }
            }

            $0.test(name: "map", decoding: bson,
                expecting: ["a", "b", "c", "d"])
            {
                try $0["four"].decode(as: BSON.Array<ArraySlice<UInt8>>.self)
                {
                    try $0.map { try $0.decode(to: String.self) }
                }
            }

            $0.test(name: "map-invalid", decoding: bson,
                failure: BSON.RecursiveError<String>.init(
                    BSON.RecursiveError<Int>.init(
                        BSON.PrimitiveError<String>.init(variant: .int32), in: 2),
                    in: "heterogenous"))
            {
                try $0["heterogenous"].decode(as: BSON.Array<ArraySlice<UInt8>>.self)
                {
                    try $0.map { try $0.decode(to: String.self) }
                }
            }

            $0.test(name: "element", decoding: bson, expecting: "c")
            {
                try $0["four"].decode
                {
                    let bson:BSON.Array<ArraySlice<UInt8>> =
                        try $0.as(BSON.Array<ArraySlice<UInt8>>.self) { 2 < $0 }
                    return try bson[2].decode(to: String.self)
                }
            }

            $0.test(name: "element-invalid", decoding: bson,
                failure: BSON.RecursiveError<String>.init(
                    BSON.RecursiveError<Int>.init(
                        BSON.PrimitiveError<String>.init(variant: .int32), in: 2),
                    in: "heterogenous"))
            {
                try $0["heterogenous"].decode
                {
                    let bson:BSON.Array<ArraySlice<UInt8>> =
                        try $0.as(BSON.Array<ArraySlice<UInt8>>.self) { 2 < $0 }
                    return try bson[2].decode(to: String.self)
                }
            }
        }
        
        tests.group("document")
        {
            let degenerate:BSON.Document<[UInt8]> =
            [
                "present": .null,
                "present": true,
            ]
            let bson:BSON.Document<[UInt8]> =
            [
                "present": .null,
                "inhabited": true,
            ]

            $0.test(name: "key-not-unique", decoding: degenerate,
                failure: BSON.DictionaryKeyError.duplicate("present"))
            {
                try $0["not-present"].decode(to: Bool.self)
            }

            $0.test(name: "key-not-present", decoding: bson,
                failure: BSON.DictionaryKeyError.undefined("not-present"))
            {
                try $0["not-present"].decode(to: Bool.self)
            }

            $0.test(name: "key-matching", decoding: bson,
                expecting: true)
            {
                try $0["inhabited"].decode(to: Bool.self)
            }

            $0.test(name: "key-not-matching", decoding: bson,
                failure: BSON.RecursiveError<String>.init(
                    BSON.PrimitiveError<String>.init(variant: .bool),
                    in: "inhabited"))
            {
                try $0["inhabited"].decode(to: String.self)
            }

            $0.test(name: "key-not-matching-inhabited", decoding: bson,
                failure: BSON.RecursiveError<String>.init(
                    BSON.PrimitiveError<Bool>.init(variant: .null),
                    in: "present"))
            {
                try $0["present"].decode(to: Bool.self)
            }

            $0.test(name: "key-inhabited", decoding: bson,
                expecting: .some(true))
            {
                try $0["inhabited"].decode(to: Bool?.self)
            }

            $0.test(name: "key-null", decoding: bson,
                expecting: nil)
            {
                try $0["present"].decode(to: Bool?.self)
            }

            $0.test(name: "key-optional", decoding: bson,
                expecting: nil)
            {
                try $0["not-present"]?.decode(to: Bool.self)
            }

            $0.test(name: "key-optional-null", decoding: bson,
                expecting: .some(.none))
            {
                try $0["present"]?.decode(to: Bool?.self)
            }

            $0.test(name: "key-optional-inhabited", decoding: bson,
                expecting: .some(.some(true)))
            {
                try $0["inhabited"]?.decode(to: Bool?.self)
            }

            // should throw an error instead of returning [`nil`]().
            $0.test(name: "key-optional-not-inhabited", decoding: bson,
                failure: BSON.RecursiveError<String>.init(
                    BSON.PrimitiveError<Bool>.init(variant: .null),
                    in: "present"))
            {
                try $0["present"]?.decode(to: Bool.self)
            }
        }

        try tests.summarize()
    }
}
extension UnitTests
{
    mutating
    func test<Failure, Unexpected>(name:String, decoding bson:BSON.Document<[UInt8]>, 
        failure:Failure,
        decoder decode:(BSON.Dictionary<ArraySlice<UInt8>>) throws -> Unexpected)
        where Failure:Equatable & Error
    {
        self.do(expecting: failure, name: name)
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

import Testing
import BSONEncoding

@main 
enum Main:SynchronousTests
{
    static
    func run(tests:inout Tests)
    {
        tests.group("literal-inference")
        {
            $0.test(name: "integer",
                encoded: .init
                {
                    $0["default"] = 1
                    $0["int32"] = 1 as Int32
                    $0["int64"] = 1 as Int64
                    $0["uint64"] = 1 as UInt64
                },
                literal:
                [
                    "default": 1,
                    "int32": .int32(1),
                    "int64": .int64(1),
                    "uint64": .uint64(1),
                ])
            
            $0.test(name: "floating-point",
                encoded: .init
                {
                    $0["default"] = 1.0
                    $0["a"] = 1.0 as Float
                    $0["b"] = 1.0 as Double
                    $0["c"] = 1.0 as Float80
                },
                literal:
                [
                    "default": 1.0,
                    "a": .double(1.0),
                    "b": .double(1.0),
                    "c": .double(1.0),
                ])
            
            $0.test(name: "string",
                encoded: .init
                {
                    $0["a"] = "string"
                    $0["b"] = "string"
                    $0["c"] = "string" as BSON.UTF8<[UInt8]>
                    $0["d"] = "string" as BSON.UTF8<[UInt8]>
                },
                literal:
                [
                    "a": "string",
                    "b": "string",
                    "c": .string("string" as BSON.UTF8<[UInt8]>),
                    "d": .string("string" as BSON.UTF8<[UInt8]>),
                ])
            
            $0.test(name: "optionals",
                encoded: .init
                {
                    $0["a"] = [1, nil, 3]
                    $0["b"] = [1, nil, 3]
                    $0["c"] = [1, .null, 3] as BSON.Tuple<[UInt8]>
                    $0["d"] = [1, .null, 3] as BSON.Tuple<[UInt8]>
                },
                literal:
                [
                    "a": [1, .null, 3],
                    "b": .tuple([1, .null, 3]),
                    "c": [1, .null, 3],
                    "d": .tuple([1, .null, 3]),
                ])
            
            $0.test(name: "tuple",
                encoded: .init
                {
                    $0["a"] = [1, 2, 3]
                    $0["b"] = [1, 2, 3]
                    $0["c"] = [1, 2, 3] as BSON.Tuple<[UInt8]>
                    $0["d"] = [1, 2, 3] as BSON.Tuple<[UInt8]>
                },
                literal:
                [
                    "a": [1, 2, 3],
                    "b": .tuple([1, 2, 3]),
                    "c": [1, 2, 3],
                    "d": .tuple([1, 2, 3]),
                ])
            
            $0.test(name: "document",
                encoded: .init
                {
                    $0["a"] = ["a": 1, "b": 2, "c": 3]
                    $0["b"] = ["a": 1, "b": 2, "c": 3]
                    $0["c"] = ["a": 1, "b": 2, "c": 3] as BSON.Document<[UInt8]>
                    $0["d"] = ["a": 1, "b": 2, "c": 3] as BSON.Document<[UInt8]>
                },
                literal:
                [
                    "a": ["a": 1, "b": 2, "c": 3],
                    "b": .document(["a": 1, "b": 2, "c": 3]),
                    "c": ["a": 1, "b": 2, "c": 3],
                    "d": .document(["a": 1, "b": 2, "c": 3]),
                ])
        }
        tests.group("type-inference")
        {
            $0.test(name: "binary",
                encoded: .init
                {
                    $0["a"] = BSON.Binary<[UInt8]>.init(subtype: .generic,
                        bytes: [0xff, 0xff, 0xff])
                },
                literal:
                [
                    "a": .binary(.init(subtype: .generic,
                        bytes: [0xff, 0xff, 0xff])),
                ])
            
            $0.test(name: "max",
                encoded: .init
                {
                    $0["max"] = BSON.Max.init()
                },
                literal:
                [
                    "max": .max,
                ])
            
            $0.test(name: "min",
                encoded: .init
                {
                    $0["min"] = BSON.Min.init()
                },
                literal:
                [
                    "min": .min,
                ])
            
            $0.test(name: "null",
                encoded: .init
                {
                    $0["null"] = ()
                },
                literal:
                [
                    "null": .null,
                ])
        }
        tests.group("elided-collections")
        {
            $0.test(name: "string",
                encoded: .init
                {
                    $0["a", elide: true] = ""
                    $0["b", elide: true] = "foo"
                    $0["c", elide: false] = "foo"
                    $0["d", elide: false] = ""
                },
                literal:
                [
                    "b": "foo",
                    "c": "foo",
                    "d": "",
                ])
            
            $0.test(name: "array",
                encoded: .init
                {
                    $0["a", elide: true] = [] as [Int]
                    $0["b", elide: true] = [1] as [Int]
                    $0["c", elide: false] = [1] as [Int]
                    $0["d", elide: false] = [] as [Int]
                },
                literal:
                [
                    "b": [1],
                    "c": [1],
                    "d": [],
                ])
            
            $0.test(name: "document",
                encoded: .init
                {
                    $0["a", elide: true] = [:]
                    $0["b", elide: true] = ["x": 1]
                    $0["c", elide: false] = ["x": 1]
                    $0["d", elide: false] = [:]
                },
                literal:
                [
                    "b": ["x": 1],
                    "c": ["x": 1],
                    "d": [:],
                ])
        }
        tests.group("elided-fields")
        {
            $0.test(name: "null",
                encoded: .init
                {
                    $0["elided"] = nil as ()?
                    $0["inhabited"] = ()
                },
                literal:
                [
                    "inhabited": .null,
                ])
            
            $0.test(name: "integer",
                encoded: .init
                {
                    $0["elided"] = nil as Int?
                    $0["inhabited"] = 5
                },
                literal:
                [
                    "inhabited": 5,
                ])
            
            $0.test(name: "optional",
                encoded: .init
                {
                    $0["elided"] = nil as Int??
                    $0["inhabited"] = (5 as Int?) as Int??
                    $0["uninhabited"] = (nil as Int?) as Int??
                },
                literal:
                [
                    "inhabited": 5,
                    "uninhabited": .null,
                ])
        }
        tests.group("duplicate-fields")
        {
            $0.test(name: "integer",
                encoded: .init
                {
                    $0["inhabited"] = 5
                    $0["uninhabited"] = nil as ()?
                    $0["inhabited"] = 7
                    $0["uninhabited"] = nil as ()?
                },
                literal:
                [
                    "inhabited": 5,
                    "inhabited": 7,
                ])
        }
    }
}

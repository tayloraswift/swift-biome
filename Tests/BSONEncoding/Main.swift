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
                    $0["a"] = -1
                    $0["b"] = -1 as Int32
                    $0["c"] = -1 as BSON.Value<[UInt8]>
                },
                literal:
                [
                    "a": -1,
                    "b": .int32(-1),
                    "c": -1 as BSON.Value<[UInt8]>,
                ])
            
            $0.test(name: "tuple",
                encoded: .init
                {
                    $0["a"] = [1, 2, 3]
                    $0["b"] = [1, 2, 3] as [_]
                    $0["c"] = [1, 2, 3] as BSON.Value<[UInt8]>
                },
                literal:
                [
                    "a": [1, 2, 3],
                    "b": .tuple([1, 2, 3]),
                    "c": [1, 2, 3] as BSON.Value<[UInt8]>,
                ])
            
            $0.test(name: "document",
                encoded: .init
                {
                    $0["a"] = ["a": 1, "b": 2, "c": 3]
                    $0["b"] = ["a": 1, "b": 2, "c": 3]
                    $0["c"] = ["a": 1, "b": 2, "c": 3]
                },
                literal:
                [
                    "a": ["a": 1, "b": 2, "c": 3],
                    "b": .document(["a": 1, "b": 2, "c": 3]),
                    "c": ["a": 1, "b": 2, "c": 3] as BSON.Value<[UInt8]>,
                ])
        }
        tests.group("optional-fields")
        {
            $0.test(name: "null",
                encoded: .init
                {
                    $0["inhabited"] = .null
                    $0["uninhabited"] = nil as Int?
                },
                literal:
                [
                    "inhabited": .null,
                ])
            
            $0.test(name: "integer",
                encoded: .init
                {
                    $0["inhabited"] = 5
                    $0["uninhabited"] = nil as Int?
                },
                literal:
                [
                    "inhabited": 5,
                ])
        }
        tests.group("duplicate-fields")
        {
            $0.test(name: "integer",
                encoded: .init
                {
                    $0["inhabited"] = 5
                    $0["uninhabited"] = nil as Int?
                    $0["inhabited"] = 7
                    $0["uninhabited"] = nil as Int?
                },
                literal:
                [
                    "inhabited": 5,
                    "inhabited": 7,
                ])
        }
    }
}

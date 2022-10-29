import Testing
import Base16
import _BSON

@main 
enum Main
{
    static 
    func main() throws
    {
        var tests:UnitTests = .init()

        // https://github.com/mongodb/specifications/blob/master/source/bson-corpus/tests/array.json
        tests.group("tuple")
        {
            $0.test(name: "empty",
                canonical: "0D000000046100050000000000", 
                expected: ["a": []])
            $0.test(name: "single-element",
                canonical: "140000000461000C0000001030000A0000000000", 
                expected: ["a": [.int32(10)]])
            
            $0.test(name: "single-element-empty-key",
                degenerate: "130000000461000B00000010000A0000000000", 
                canonical: "140000000461000C0000001030000A0000000000", 
                expected: ["a": [.int32(10)]])
            
            $0.test(name: "single-element-invalid-key",
                degenerate: "150000000461000D000000106162000A0000000000", 
                canonical: "140000000461000C0000001030000A0000000000", 
                expected: ["a": [.int32(10)]])
            
            $0.test(name: "multiple-element-duplicate-keys",
                degenerate: "1b000000046100130000001030000a000000103000140000000000", 
                canonical: "1b000000046100130000001030000a000000103100140000000000", 
                expected: ["a": [.int32(10), .int32(20)]])
            
            $0.test(name: "invalid-length-over",
                invalid: "140000000461000D0000001030000A0000000000",
                failure: BSON.EndOfInputError.unexpected)
            
            $0.test(name: "invalid-length-under",
                invalid: "140000000461000B0000001030000A0000000000",
                failure: BSON.EndOfInputError.expected(encountered: 1))
            
            $0.test(name: "invalid-element",
                invalid: "1A00000004666F6F00100000000230000500000062617A000000",
                failure: BSON.EndOfInputError.unexpected)
        }
        
        
        // https://github.com/mongodb/specifications/blob/master/source/bson-corpus/tests/binary.json
        tests.group("binary")
        {
            $0.test(name: "generic-empty",
                canonical: "0D000000057800000000000000",
                expected: ["x": .binary(.init(subtype: .generic, bytes: []))])
            
            $0.test(name: "generic",
                canonical: "0F0000000578000200000000FFFF00",
                expected: ["x": .binary(.init(subtype: .generic,
                    bytes: Base16.decode(utf8: "ffff".utf8)!))])
            
            $0.test(name: "function",
                canonical: "0F0000000578000200000001FFFF00",
                expected: ["x": .binary(.init(subtype: .function,
                    bytes: Base16.decode(utf8: "ffff".utf8)!))])
            
            $0.test(name: "uuid",
                canonical: "1D000000057800100000000473FFD26444B34C6990E8E7D1DFC035D400", 
                expected: ["x": .binary(.init(subtype: .uuid,
                    bytes: Base16.decode(utf8: "73ffd26444b34c6990e8e7d1dfc035d4".utf8)!))])
            
            $0.test(name: "md5",
                canonical: "1D000000057800100000000573FFD26444B34C6990E8E7D1DFC035D400", 
                expected: ["x": .binary(.init(subtype: .md5,
                    bytes: Base16.decode(utf8: "73ffd26444b34c6990e8e7d1dfc035d4".utf8)!))])
            
            $0.test(name: "compressed",
                canonical: "1D000000057800100000000773FFD26444B34C6990E8E7D1DFC035D400", 
                expected: ["x": .binary(.init(subtype: .compressed,
                    bytes: Base16.decode(utf8: "73ffd26444b34c6990e8e7d1dfc035d4".utf8)!))])
            
            $0.test(name: "custom",
                canonical: "0F0000000578000200000080FFFF00",
                expected: ["x": .binary(.init(subtype: .custom(code: 0x80),
                    bytes: Base16.decode(utf8: "ffff".utf8)!))])
            
            $0.test(name: "invalid-length-over",
                invalid: "1D000000057800FF0000000573FFD26444B34C6990E8E7D1DFC035D400",
                failure: BSON.EndOfInputError.unexpected)
            
            $0.test(name: "invalid-length-negative",
                invalid: "0D000000057800FFFFFFFF0000",
                failure: BSON.BinarySubtypeError.missing)
            // TODO: tests for legacy binary subtype 0x02

        }

        // https://github.com/mongodb/specifications/blob/master/source/bson-corpus/tests/boolean.json
        tests.group("bool")
        {
            $0.test(name: "true",
                canonical: "090000000862000100",
                expected: ["b": true])
            $0.test(name: "false",
                canonical: "090000000862000000",
                expected: ["b": false])
            
            $0.test(name: "invalid-subtype",
                invalid: "090000000862000200",
                failure: BSON.BooleanSubtypeError.invalid(2))
            
            $0.test(name: "invalid-subtype-negative",
                invalid: "09000000086200FF00",
                failure: BSON.BooleanSubtypeError.invalid(255))
        }

        // https://github.com/mongodb/specifications/blob/master/source/bson-corpus/tests/code.json
        tests.group("javascript")
        {
            $0.test(name: "empty",
                canonical: "0D0000000D6100010000000000",
                expected: ["a": .javascript("")])
            
            $0.test(name: "single-character",
                canonical: "0E0000000D610002000000620000",
                expected: ["a": .javascript("b")])
            
            $0.test(name: "multiple-character",
                canonical: "190000000D61000D0000006162616261626162616261620000",
                expected: ["a": .javascript("abababababab")])
            
            $0.test(name: "utf-8-double-code-unit",
                canonical: "190000000D61000D000000C3A9C3A9C3A9C3A9C3A9C3A90000",
                expected: ["a": .javascript("\u{e9}\u{e9}\u{e9}\u{e9}\u{e9}\u{e9}")])
            
            $0.test(name: "utf-8-triple-code-unit",
                canonical: "190000000D61000D000000E29886E29886E29886E298860000",
                expected: ["a": .javascript("\u{2606}\u{2606}\u{2606}\u{2606}")])
            
            $0.test(name: "utf-8-null-bytes",
                canonical: "190000000D61000D0000006162006261620062616261620000",
                expected: ["a": .javascript("ab\u{00}bab\u{00}babab")])
            
            $0.test(name: "missing-trailing-null-byte",
                invalid: "0C0000000D61000000000000",
                failure: BSON.EndOfUTF8Error.unexpected)
            
            $0.test(name: "invalid-length-negative",
                invalid: "0C0000000D6100FFFFFFFF00",
                failure: BSON.HeaderError<BSON.UTF8<ArraySlice<UInt8>>>.init(length: -1))
            
            $0.test(name: "invalid-length-over",
                invalid: "100000000D6100050000006200620000",
                failure: BSON.EndOfInputError.unexpected)
            
            $0.test(name: "invalid-length-over-document",
                invalid: "120000000D00FFFFFF00666F6F6261720000",
                failure: BSON.EndOfInputError.unexpected)
            
            $0.test(name: "invalid-length-under",
                invalid: "0E0000000D610001000000000000",
                failure: BSON.EndOfInputError.expected(encountered: 1))
        }

        // https://github.com/mongodb/specifications/blob/master/source/bson-corpus/tests/code_w_scope.json
        tests.group("javascript-scope")
        {
            $0.test(name: "empty",
                canonical: "160000000F61000E0000000100000000050000000000",
                expected: ["a": .javascriptScope([:], "")])
            
            $0.test(name: "empty-scope",
                canonical: "1A0000000F610012000000050000006162636400050000000000",
                expected: ["a": .javascriptScope([:], "abcd")])
            
            $0.test(name: "empty-code",
                canonical: "1D0000000F61001500000001000000000C000000107800010000000000",
                expected: ["a": .javascriptScope(["x": .int32(1)], "")])
            
            $0.test(name: "non-empty",
                canonical: "210000000F6100190000000500000061626364000C000000107800010000000000",
                expected: ["a": .javascriptScope(["x": .int32(1)], "abcd")])
            
            $0.test(name: "unicode",
                canonical: "1A0000000F61001200000005000000C3A9006400050000000000",
                expected: ["a": .javascriptScope([:], "\u{e9}\u{00}d")])
            
            // note: we do not validate the redundant field length,
            // so those tests are not included

            // note: the length is actually too short, but because we use the component-wise
            // length headers instead of the field length, this manifests itself as a
            // frameshift error.
            $0.test(name: "invalid-length-frameshift-clips-scope",
                invalid: "280000000F6100200000000400000061626364001300000010780001000000107900010000000000",
                failure: BSON.EndOfInputError.unexpected)
            
            $0.test(name: "invalid-length-over",
                invalid: "280000000F6100200000000600000061626364001300000010780001000000107900010000000000",
                failure: BSON.EndOfInputError.unexpected)
            // note: frameshift
            $0.test(name: "invalid-length-frameshift",
                invalid: "280000000F610020000000FF00000061626364001300000010780001000000107900010000000000",
                failure: BSON.EndOfInputError.unexpected)
            
            $0.test(name: "invalid-scope",
                invalid: "1C0000000F001500000001000000000C000000020000000000000000",
                failure: BSON.EndOfUTF8Error.unexpected)
        }

        // https://github.com/mongodb/specifications/blob/master/source/bson-corpus/tests/datetime.json
        tests.group("millisecond")
        {
            $0.test(name: "epoch",
                canonical: "10000000096100000000000000000000",
                expected: ["a": .millisecond(0)])
            
            $0.test(name: "positive",
                canonical: "10000000096100C5D8D6CC3B01000000",
                expected: ["a": .millisecond(1356351330501)])
            
            $0.test(name: "negative",
                canonical: "10000000096100C33CE7B9BDFFFFFF00",
                expected: ["a": .millisecond(-284643869501)])
            
            $0.test(name: "positive-2",
                canonical: "1000000009610000DC1FD277E6000000",
                expected: ["a": .millisecond(253402300800000)])
            
            $0.test(name: "positive-3",
                canonical: "10000000096100D1D6D6CC3B01000000",
                expected: ["a": .millisecond(1356351330001)])
            
            $0.test(name: "truncated",
                invalid: "0C0000000961001234567800",
                failure: BSON.EndOfInputError.unexpected)
        }
        
        try tests.summarize()
    }
}
extension UnitTests
{
    mutating
    func test<Failure>(name:String, invalid:String, failure:Failure)
        where Failure:Error & Equatable
    {
        let invalid:[UInt8] = Base16.decode(utf8: invalid.utf8)!
        let document:BSON.Document<ArraySlice<UInt8>> = .init(
            slicing: invalid.dropFirst(4))
        self.do(expecting: failure, name: name)
        {
            _ in _ = try document.canonicalized()
        }
    }
    mutating
    func test(name:String, degenerate:String? = nil, canonical:String, 
        expected:BSON.Document<[UInt8]>)
    {
        let canonical:[UInt8] = Base16.decode(utf8: canonical.utf8)!
        let size:Int32 = canonical.prefix(4).withUnsafeBytes
        {
            .init(littleEndian: $0.load(as: Int32.self))
        }

        let document:BSON.Document<ArraySlice<UInt8>> = .init(
            slicing: canonical.dropFirst(4))

        self.assert(canonical.count ==? .init(size), name: "\(name).document-encoded-header")
        self.assert(document.header ==? size, name: "\(name).document-computed-header")

        self.assert(expected ~~ document, name: "\(name).canonical-equivalence")
        self.assert(expected == document, name: "\(name).binary-equivalence")

        if  let degenerate:String
        {
            let degenerate:[UInt8] = Base16.decode(utf8: degenerate.utf8)!
            let document:BSON.Document<ArraySlice<UInt8>> = .init(
                slicing: degenerate.dropFirst(4))
            self.do(name: "\(name).canonicalization")
            {
                let canonicalized:BSON.Document<ArraySlice<UInt8>> = 
                    try document.canonicalized()
                
                $0.assert(expected ~~ document,
                    name: "\(name).canonicalized-canonical-equivalence")
                $0.assert(expected == canonicalized,
                    name: "\(name).canonicalized-binary-equivalence")
            }
        }
    }
}

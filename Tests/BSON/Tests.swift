import Base16
import BSON
import Testing

extension Tests
{
    mutating
    func test<Failure>(name:String, invalid:String, failure:Failure)
        where Failure:Error & Equatable
    {
        let invalid:[UInt8] = Base16.decode(invalid.utf8)
        self.do(name: name, expecting: failure)
        {
            _ in
            var input:BSON.Input<[UInt8]> = .init(invalid)
            let document:BSON.Document<ArraySlice<UInt8>> = try input.parse(
                as: BSON.Document<ArraySlice<UInt8>>.self)
            try input.finish()
            _ = try document.canonicalized()
        }
    }
    mutating
    func test(name:String, degenerate:String? = nil, canonical:String, 
        expected:BSON.Document<[UInt8]>)
    {
        self.group(name)
        {
            let canonical:[UInt8] = Base16.decode(canonical.utf8)
            let size:Int32 = canonical.prefix(4).withUnsafeBytes
            {
                .init(littleEndian: $0.load(as: Int32.self))
            }

            let document:BSON.Document<ArraySlice<UInt8>> = .init(
                slicing: canonical.dropFirst(4).dropLast())

            $0.assert(canonical.count ==? .init(size), name: "document-encoded-header")
            $0.assert(document.header ==? size, name: "document-computed-header")

            $0.assert(expected ~~ document, name: "canonical-equivalence")
            $0.assert(expected == document, name: "binary-equivalence")

            if  let degenerate:String
            {
                let degenerate:[UInt8] = Base16.decode(degenerate.utf8)
                let document:BSON.Document<ArraySlice<UInt8>> = .init(
                    slicing: degenerate.dropFirst(4).dropLast())
                $0.do(name: "canonicalization")
                {
                    let canonicalized:BSON.Document<ArraySlice<UInt8>> = 
                        try document.canonicalized()
                    
                    $0.assert(expected ~~ document,
                        name: "canonicalized-canonical-equivalence")
                    $0.assert(expected == canonicalized,
                        name: "canonicalized-binary-equivalence")
                }
            }
        }
    }
}

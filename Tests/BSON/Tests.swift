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
        let document:BSON.Document<ArraySlice<UInt8>> = .init(
            slicing: invalid.dropFirst(4))
        self.do(name: name, expecting: failure)
        {
            _ in _ = try document.canonicalized()
        }
    }
    mutating
    func test(name:String, degenerate:String? = nil, canonical:String, 
        expected:BSON.Document<[UInt8]>)
    {
        let canonical:[UInt8] = Base16.decode(canonical.utf8)
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
            let degenerate:[UInt8] = Base16.decode(degenerate.utf8)
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

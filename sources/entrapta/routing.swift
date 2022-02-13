import Grammar 

extension Entrapta 
{
    fileprivate static 
    func hex(_ value:UInt8) -> UInt8
    {
        (value < 10 ? 0x30 : 0x57) + value 
    }
    fileprivate static 
    func normalize(byte:UInt8) -> UInt8?
    {
        switch byte 
        {
        case    0x41 ... 0x5a:  // [A-Z] -> [a-z]
            return byte | 0x20
        case    0x30 ... 0x39,  // [0-9]
                0x61 ... 0x7a,  // [a-z]
                0x2d,           // '-'
                0x2e,           // '.'
                // not technically a URL character, but browsers won’t render '%3A' 
                // in the URL bar, and ':' is so common in Swift it is not worth 
                // percent-encoding
                0x3a,           // ':' 
                0x5f,           // '_'
                0x7e:           // '~'
            return byte 
        default: 
            return nil 
        }
    }

    static 
    func normalize(path:[String]) -> String 
    {
        var encoded:[UInt8] = []
        for component:String in path 
        {
            encoded.append(0x2f) // '/'
            for byte:UInt8 in component.utf8 
            {
                if let unencoded:UInt8 = Self.normalize(byte: byte)
                {
                    encoded.append(unencoded)
                }
                else 
                {
                    // percent-encode
                    encoded.append(0x25) // '%'
                    encoded.append(Self.hex(byte >> 4))
                    encoded.append(Self.hex(byte & 0x0f))
                }
            }
        }
        return String.init(unsafeUninitializedCapacity: encoded.count)
        {
            $0.initialize(from: encoded)
            return encoded.count
        }
    }
    static 
    func normalize(path:String) -> String 
    {
        (try? Grammar.parse(path.utf8, as: URL<String.Index>.Path.self)) ?? path
    }
    
    enum URL<Location> 
    {
        typealias ASCII     = Grammar.Encoding<Location, UInt8>.ASCII 
        typealias Digit<T>  = Grammar.Digit<Location, UInt8, T>.ASCII where T:BinaryInteger
    }
}
extension Entrapta.URL
{
    enum Path:ParsingRule
    {
        typealias Terminal = UInt8
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> String
            where   Diagnostics:ParsingDiagnostics, 
                    Diagnostics.Source.Index == Location, Diagnostics.Source.Element == Terminal
        {
            var utf8:[UInt8] = []
            while let head:UInt8 = input.next() 
            {
                guard head != 0x2f // '/'
                else 
                {
                    utf8.append(head)
                    continue 
                }
                let byte:UInt8 
                if head == 0x25 // '%'
                {
                    let digit:(UInt8, UInt8) = try input.parse(as: (Digit<UInt8>.Hex.Anycase, Digit<UInt8>.Hex.Anycase).self)
                    byte = digit.0 << 4 | digit.1
                }
                else 
                {
                    byte = head 
                }
                if let unencoded:UInt8 = Entrapta.normalize(byte: byte)
                {
                    // this is a byte that should not have been percent-encoded 
                    utf8.append(unencoded)
                }
                else 
                {
                    // leave it be (but lowercase the percent-encoding if needed)
                    utf8.append(0x25) // '%'
                    utf8.append(Entrapta.hex(byte >> 4))
                    utf8.append(Entrapta.hex(byte & 0x0f))
                }
            }
            return String.init(unsafeUninitializedCapacity: utf8.count)
            {
                $0.initialize(from: utf8)
                return utf8.count
            }
        }
    }
}

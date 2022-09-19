import Grammar 

extension Tag.Semantic 
{
    @inlinable public 
    init(parsing string:some StringProtocol) throws 
    {
        self = try Tag.Rule<String.Index>.Semantic.parse(string.unicodeScalars)
    }
}
extension Tag 
{
    public 
    struct Rule<Location>
    {
        public 
        typealias Terminal = Unicode.Scalar
        public 
        typealias Encoding = UnicodeEncoding<Location, Terminal>

        public 
        typealias Integer = Pattern.UnsignedInteger<
            UnicodeDigit<Location, Unicode.Scalar, UInt16>.DecimalScalar>
        
        public 
        enum Semantic:ParsingRule 
        {
            public
            typealias Terminal = Unicode.Scalar
            
            @inlinable public static 
            func parse<Source>(_ input:inout ParsingInput<some ParsingDiagnostics<Source>>) 
                throws -> Tag.Semantic
                where Source:Collection<Unicode.Scalar>, Source.Index == Location
            {
                let first:UInt16 = try input.parse(as: Integer.self)

                guard case let (_, minor)? = 
                    try? input.parse(as: (Encoding.Period, Integer).self)
                else 
                {
                    return .major(first)
                }
                guard case let (_, patch)? = 
                    try? input.parse(as: (Encoding.Period, Integer).self)
                else 
                {
                    return .minor(first, minor)
                }

                return .patch(first, minor, patch)
            }
        }
    }
}
import Grammar

extension MaskedVersion 
{
    public 
    struct Rule<Location>:ParsingRule 
    {
        public 
        typealias Terminal = Unicode.Scalar
        public 
        typealias Encoding = UnicodeEncoding<Location, Terminal>
    }
}
extension MaskedVersion.Rule 
{
    public 
    typealias Integer = Pattern.UnsignedInteger<
        UnicodeDigit<Location, Unicode.Scalar, UInt16>.DecimalScalar>
    
    public 
    enum Hour:TerminalRule
    {
        public 
        typealias Terminal = Unicode.Scalar
        public 
        typealias Construction = UInt8
        
        @inlinable public static 
        func parse(terminal:Terminal) -> UInt8?
        {
            switch terminal 
            {
            case "a" ... "z":   return .init(ascii: terminal)
            //case "A" ... "Z":   return terminal.lowercased()
            default:            return nil
            }
        }
    }
    public 
    enum Swift:LiteralRule 
    {
        public
        typealias Terminal = Unicode.Scalar
        
        @inlinable public static
        var literal:String.UnicodeScalarView 
        {
            "swift".unicodeScalars
        }
    }
    public 
    enum Release:LiteralRule 
    {
        public
        typealias Terminal = Unicode.Scalar
        
        @inlinable public static
        var literal:String.UnicodeScalarView 
        {
            "RELEASE".unicodeScalars
        }
    }
    public 
    enum DevelopmentSnapshot:LiteralRule 
    {
        public
        typealias Terminal = Unicode.Scalar
        
        @inlinable public static
        var literal:String.UnicodeScalarView 
        {
            "DEVELOPMENT-SNAPSHOT".unicodeScalars
        }
    }
    public 
    enum Toolchain:ParsingRule 
    {
        public
        typealias Terminal = Unicode.Scalar
        
        @inlinable public static 
        func parse<Source>(_ input:inout ParsingInput<some ParsingDiagnostics<Source>>) 
            throws -> MaskedVersion
            where Source:Collection<Unicode.Scalar>, Source.Index == Location
        {
            try input.parse(as: Swift.self)
            try input.parse(as: Encoding.Hyphen.self)
            if case _? = input.parse(as: DevelopmentSnapshot?.self)
            {
                try input.parse(as: Encoding.Hyphen.self)
                let year:UInt16 = try input.parse(as: Integer.self)
                try input.parse(as: Encoding.Hyphen.self)
                let month:UInt16 = try input.parse(as: Integer.self)
                try input.parse(as: Encoding.Hyphen.self)
                let day:UInt16 = try input.parse(as: Integer.self)
                try input.parse(as: Encoding.Hyphen.self)
                let hour:UInt8 = try input.parse(as: Hour.self)
                
                return .hourly(year: year, month: month, day: day, letter: hour)
            }
            else 
            {
                let semantic:MaskedVersion = try input.parse(as: Semantic.self)
                try input.parse(as: Encoding.Hyphen.self)
                try input.parse(as: Release.self)
                return semantic
            }
        }
    }
    // will only parse up to 3 components 
    public 
    enum Semantic:ParsingRule 
    {
        public 
        typealias Terminal = Unicode.Scalar
        
        @inlinable public static 
        func parse<Source>(_ input:inout ParsingInput<some ParsingDiagnostics<Source>>) 
            throws -> MaskedVersion
            where Source:Collection<Unicode.Scalar>, Source.Index == Location
        {
            let first:UInt16 = try input.parse(as: Integer.self)
            if  case let (_, minor)? = 
                try? input.parse(as: (Encoding.Period, Integer).self)
            {
                if  case let (_, patch)? = 
                    try? input.parse(as: (Encoding.Period, Integer).self)
                {
                    return .patch(first, minor, patch)
                }
                else 
                {
                    return .minor(first, minor)
                }
            }
            else 
            {
                return .major(first)
            }
        }
    }
    
    @inlinable public static 
    func parse<Source>(_ input:inout ParsingInput<some ParsingDiagnostics<Source>>) 
        throws -> MaskedVersion
        where Source:Collection<Unicode.Scalar>, Source.Index == Location
    {
        let first:UInt16 = try input.parse(as: Integer.self)
        guard case nil = input.parse(as: Encoding.Hyphen?.self)
        else 
        {
            // parse a date 
            let month:UInt16 = try input.parse(as: Integer.self)
            try input.parse(as: Encoding.Hyphen.self)
            let day:UInt16 = try input.parse(as: Integer.self)
            
            guard case let (_, letter)? = try?
                input.parse(as: (Encoding.Hyphen, Hour).self)
            else 
            {
                return .nightly(year: first, month: month, day: day)
            }
            return .hourly(year: first, month: month, day: day, letter: letter)
        }
        // parse a x.y.z.w semantic version. the w component is 
        // a documentation version, which is a sub-patch increment
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
        guard case let (_, edition)? = 
            try? input.parse(as: (Encoding.Period, Integer).self)
        else 
        {
            return .patch(first, minor, patch)
        }
        return .edition(first, minor, patch, edition)
    }
}
import Grammar
import PackageResolution

public
enum Tag:Hashable, Sendable 
{
    public 
    enum Semantic:Hashable, Sendable
    {
        case major(UInt16)
        case minor(UInt16, UInt16)
        case patch(UInt16, UInt16, UInt16)
        case edition(UInt16, UInt16, UInt16, UInt16)
    }
    public 
    enum Toolchain:Hashable, Sendable
    {
        case nightly(year:UInt16, month:UInt16, day:UInt16)
        case hourly(year:UInt16, month:UInt16, day:UInt16, letter:UInt8)
    }

    case toolchain(Toolchain)
    case semantic(Semantic)
    case named(String)

    init?(parsing string:some StringProtocol) 
    {
        if string.isEmpty 
        {
            return nil 
        }
        self =  (try? Rule<String.Index>.Concise.parse(string.unicodeScalars)) ?? 
                (try? Rule<String.Index>.Toolchain.parse(string.unicodeScalars)) ?? 
                .named(String.init(string))
    }

    init?(_ requirement:PackageResolution.Requirement)
    {
        switch requirement 
        {
        case .version(let version): 
            self = .semantic(.patch(
                .init(version.major), 
                .init(version.minor), 
                .init(version.patch)))
        case .branch(let name): 
            self.init(parsing: name)
        }
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
    }
}
extension Tag.Rule 
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
        func parse(terminal:Unicode.Scalar) -> UInt8?
        {
            switch terminal 
            {
            case "a" ... "z":   return .init(ascii: terminal)
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
            throws -> Tag
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
                
                return .toolchain(.hourly(year: year, month: month, day: day, letter: hour))
            }
            else 
            {
                let semantic:Tag.Semantic 
                // will only parse up to 3 components 
                let first:UInt16 = try input.parse(as: Integer.self)
                if  case let (_, minor)? = 
                    try? input.parse(as: (Encoding.Period, Integer).self)
                {
                    if  case let (_, patch)? = 
                        try? input.parse(as: (Encoding.Period, Integer).self)
                    {
                        semantic = .patch(first, minor, patch)
                    }
                    else 
                    {
                        semantic = .minor(first, minor)
                    }
                }
                else 
                {
                    semantic = .major(first)
                }
                
                try input.parse(as: Encoding.Hyphen.self)
                try input.parse(as: Release.self)
                return .semantic(semantic)
            }
        }
    }
    public 
    enum Concise:ParsingRule 
    {
        public
        typealias Terminal = Unicode.Scalar
        
        @inlinable public static 
        func parse<Source>(_ input:inout ParsingInput<some ParsingDiagnostics<Source>>) 
            throws -> Tag
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
                    return .toolchain(.nightly(year: first, month: month, day: day))
                }
                return .toolchain(.hourly(year: first, month: month, day: day, letter: letter))
            }
            // parse a x.y.z.w semantic version. the w component is 
            // a documentation version, which is a sub-patch increment
            guard case let (_, minor)? = 
                try? input.parse(as: (Encoding.Period, Integer).self)
            else 
            {
                return .semantic(.major(first))
            }
            guard case let (_, patch)? = 
                try? input.parse(as: (Encoding.Period, Integer).self)
            else 
            {
                return .semantic(.minor(first, minor))
            }
            guard case let (_, edition)? = 
                try? input.parse(as: (Encoding.Period, Integer).self)
            else 
            {
                return .semantic(.patch(first, minor, patch))
            }
            return .semantic(.edition(first, minor, patch, edition))
        }
    }
}
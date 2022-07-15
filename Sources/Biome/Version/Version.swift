import JSON

infix operator ?= :ComparisonPrecedence

@usableFromInline
struct Version:Hashable, Strideable, Sendable
{
    let offset:Int 
    
    static 
    let max:Self = .init(offset: .max)
    
    @usableFromInline static 
    func < (lhs:Self, rhs:Self) -> Bool 
    {
        lhs.offset < rhs.offset 
    }
    @usableFromInline
    func advanced(by offset:Int) -> Self
    {
        .init(offset: self.offset.advanced(by: offset))
    }
    @usableFromInline
    func distance(to other:Self) -> Int
    {
        self.offset.distance(to: other.offset)
    }
}

@frozen public 
enum PreciseVersion:Hashable, CustomStringConvertible, Sendable
{
    case semantic(UInt16, UInt16, UInt16, UInt16)
    case toolchain(year:UInt16, month:UInt16, day:UInt16, letter:UInt8)
    
    @inlinable public 
    init(_ masked:MaskedVersion?)
    {
        switch masked 
        {
        case nil: 
            self = .semantic(0, 0, 0, 0)
        case .major(let major)?:
            self = .semantic(major, 0, 0, 0)
        case .minor(let major, let minor)?:
            self = .semantic(major, minor, 0, 0)
        case .patch(let major, let minor, let patch)?:
            self = .semantic(major, minor, patch, 0)
        case .edition(let major, let minor, let patch, let edition)?:
            self = .semantic(major, minor, patch, edition)
        case .nightly(year: let year, month: let month, day: let day)?:
            self = .toolchain(year: year, month: month, day: day, letter: 0x61) // 'a'
        case .hourly(year: let year, month: let month, day: let day, letter: let letter)?:
            self = .toolchain(year: year, month: month, day: day, letter: letter)
        }
    }
    
    var quadruplet:MaskedVersion 
    {
        switch self
        {
        case .semantic(let major, let minor, let patch, let edition):
            return .edition(major, minor, patch, edition)
        case .toolchain(year: let year, month: let month, day: let day, letter: let letter):
            return .hourly(year: year, month: month, day: day, letter: letter)
        }
    }
    var triplet:MaskedVersion 
    {
        switch self
        {
        case .semantic(let major, let minor, let patch, _):
            return .patch(major, minor, patch)
        case .toolchain(year: let year, month: let month, day: let day, letter: _):
            return .nightly(year: year, month: month, day: day)
        }
    }
    
    @inlinable public 
    var description:String 
    {
        switch self 
        {
        case .semantic(let major, let minor, let patch, let edition): 
            return "\(major).\(minor).\(patch).\(edition)"
        case .toolchain(year: let year, month: let month, day: let day, letter: let letter):
            return "\(year)-\(month)-\(day)-\(Unicode.Scalar.init(letter))"
        }
    }
    
    @inlinable public static
    func ?= (pattern:MaskedVersion?, precise:Self) -> Bool 
    {
        switch pattern 
        {
        case nil: 
            break
        case .major(let major)?:
            guard case .semantic(major, _, _, _) = precise 
            else 
            {
                return false 
            }
        case .minor(let major, let minor)?:
            guard case .semantic(major, minor, _, _) = precise 
            else 
            {
                return false 
            }
        case .patch(let major, let minor, let patch)?:
            guard case .semantic(major, minor, patch, _) = precise 
            else 
            {
                return false 
            }
        case .edition(let major, let minor, let patch, let edition)?:
            guard case .semantic(major, minor, patch, edition) = precise 
            else 
            {
                return false 
            }
        
        case .nightly(year: let year, month: let month, day: let day)?:
            guard case .toolchain(year: year, month: month, day: day, letter: _) = precise 
            else 
            {
                return false 
            }
        case .hourly(year: let year, month: let month, day: let day, letter: let letter)?:
            guard case .toolchain(year: year, month: month, day: day, letter: letter) = precise 
            else 
            {
                return false 
            }
        }
        return true
    }
}
    
@frozen public 
enum MaskedVersion:Hashable, CustomStringConvertible, Sendable
{
    static 
    func semantic(_ version:(major:UInt16, minor:UInt16, patch:UInt16, edition:UInt16))
        -> Self
    {
        .edition(version.major, version.minor, version.patch, version.edition)
    }
    
    case major(UInt16)
    case minor(UInt16, UInt16)
    case patch(UInt16, UInt16, UInt16)
    case edition(UInt16, UInt16, UInt16, UInt16)
    
    case nightly(year:UInt16, month:UInt16, day:UInt16)
    case hourly(year:UInt16, month:UInt16, day:UInt16, letter:UInt8)
        
    @inlinable public 
    var description:String 
    {
        switch self 
        {
        case .major(let major): 
            return "\(major)"
        case .minor(let major, let minor): 
            return "\(major).\(minor)"
        case .patch(let major, let minor, let patch): 
            return "\(major).\(minor).\(patch)"
        case .edition(let major, let minor, let patch, let edition): 
            return "\(major).\(minor).\(patch).\(edition)"
        case .nightly(year: let year, month: let month, day: let day):
            return "\(year)-\(month)-\(day)"
        case .hourly(year: let year, month: let month, day: let day, letter: let letter):
            return "\(year)-\(month)-\(day)-\(Unicode.Scalar.init(letter))"
        }
    }
    
    @inlinable public static
    func ?= (pattern:MaskedVersion?, version:Self) -> Bool 
    {
        pattern ?= .init(version)
    }
}
extension MaskedVersion 
{
    @inlinable public
    init?<S>(toolchain string:S) where S:StringProtocol
    {
        if  let version:Self = 
            try? Grammar.parse(string.unicodeScalars, as: Rule<String.Index>.Toolchain.self)
        {
            self = version 
        }
        else 
        {
            return nil 
        }
    }
    @inlinable public
    init?<S>(_ string:S) where S:StringProtocol
    {
        if  let version:Self = 
            try? Grammar.parse(string.unicodeScalars, as: Rule<String.Index>.self)
        {
            self = version 
        }
        else 
        {
            return nil 
        }
    }
    init(from json:JSON) throws 
    {
        self = try json.lint 
        {
            let major:UInt16 = try $0.remove("major", as: UInt16.self)
            guard let minor:UInt16 = try $0.pop("minor", as: UInt16.self)
            else 
            {
                return .major(major)
            }
            guard let patch:UInt16 = try $0.pop("patch", as: UInt16.self)
            else 
            {
                return .minor(major, minor)
            }
            return .patch(major, minor, patch)
        }
    }
}
extension MaskedVersion 
{
    public 
    struct Rule<Location>:ParsingRule 
    {
        public 
        typealias Terminal = Unicode.Scalar
        public 
        typealias Encoding = Grammar.Encoding<Location, Terminal>
    }
}
extension MaskedVersion.Rule 
{
    public 
    typealias Integer = Grammar.UnsignedIntegerLiteral<
                        Grammar.DecimalDigitScalar<Location, UInt16>>
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
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) 
            throws -> MaskedVersion
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any 
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
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) 
            throws -> MaskedVersion
            where Grammar.Parsable<Location, Terminal, Diagnostics>:Any 
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
    func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) 
        throws -> MaskedVersion
        where Grammar.Parsable<Location, Terminal, Diagnostics>:Any 
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

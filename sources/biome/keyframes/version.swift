import JSON

struct Version:Hashable, Comparable, Sendable
{
    let offset:Int 
    
    static 
    let max:Self = .init(offset: .max)
    
    static 
    func < (lhs:Self, rhs:Self) -> Bool 
    {
        lhs.offset < rhs.offset 
    }
}

enum PreciseVersion:Hashable, CustomStringConvertible, Sendable
{
    case semantic(UInt16, UInt16, UInt16, UInt16)
    case toolchain(year:UInt16, month:UInt16, day:UInt16, letter:UInt8)
    
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
    
    public 
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
}
extension MaskedVersion 
{
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
    struct Rule<Location>:ParsingRule 
    {
        typealias Terminal = Unicode.Scalar
        typealias Encoding = Grammar.Encoding<Location, Terminal>
    }
}
extension MaskedVersion.Rule 
{
    private 
    typealias Integer = Grammar.UnsignedIntegerLiteral<
                        Grammar.DecimalDigitScalar<Location, UInt16>>
    
    private 
    enum Hour:TerminalRule
    {
        typealias Terminal = Unicode.Scalar
        typealias Construction = UInt8
        static 
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
    
    static 
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

import Grammar 

@frozen public 
enum MaskedVersion:Hashable, CustomStringConvertible, Sendable
{
    // static 
    // func semantic(_ version:(major:UInt16, minor:UInt16, patch:UInt16, edition:UInt16))
    //     -> Self
    // {
    //     .edition(version.major, version.minor, version.patch, version.edition)
    // }
    
    case major(UInt16)
    case minor(UInt16, UInt16)
    case patch(UInt16, UInt16, UInt16)
    case edition(UInt16, UInt16, UInt16, UInt16)
    
    case nightly(year:UInt16, month:UInt16, day:UInt16)
    case hourly(year:UInt16, month:UInt16, day:UInt16, letter:UInt8)
    
    @inlinable public static
    func ?= (pattern:MaskedVersion?, version:Self) -> Bool 
    {
        pattern ?= .init(version)
    }

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
}
extension MaskedVersion:LosslessStringConvertible 
{
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
}
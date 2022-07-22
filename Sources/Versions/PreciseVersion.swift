infix operator ?= :ComparisonPrecedence

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
    @inlinable public 
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
    @inlinable public 
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

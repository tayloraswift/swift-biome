/// A BSON variant type. This enumeration also serves as a namespace for all other
/// APIs in this module.
@frozen public
enum BSON:UInt8
{
    case double             = 0x01
    case string             = 0x02
    case document           = 0x03
    case tuple              = 0x04
    case binary             = 0x05

    case id                 = 0x07
    case bool               = 0x08
    case millisecond        = 0x09
    case null               = 0x0A
    case regex              = 0x0B
    case pointer            = 0x0C
    case javascript         = 0x0D

    case javascriptScope    = 0x0F
    case int32              = 0x10
    case uint64             = 0x11
    case int64              = 0x12
    case decimal128         = 0x13

    case min                = 0xFF
    case max                = 0x7F

    /// Calls ``init(rawValue:)``, but throws a ``TypeError`` instead of returning [`nil`]().
    @inlinable public
    init(code:UInt8) throws
    {
        if let variant:Self = .init(rawValue: code)
        {
            self = variant
        }
        else
        {
            throw TypeError.init(invalid: code)
        }
    }
    /// Converts the given raw type code to a variant type. Deprecated type codes with an
    /// isomorphic encoding will be canonicalized. The ``pointer`` and ``javascriptScope``
    /// types will be preserved, because they do not have a modern equivalent.
    @inlinable public
    init?(rawValue:UInt8)
    {
        switch rawValue
        {
        case 0x01:  self = .double
        case 0x02:  self = .string
        case 0x03:  self = .document
        case 0x04:  self = .tuple
        case 0x05:  self = .binary
        case 0x06:  self = .null
        case 0x07:  self = .id
        case 0x08:  self = .bool
        case 0x09:  self = .millisecond
        case 0x0A:  self = .null
        case 0x0B:  self = .regex
        case 0x0C:  self = .pointer
        case 0x0D:  self = .javascript
        case 0x0E:  self = .string
        case 0x0F:  self = .javascriptScope
        case 0x10:  self = .int32
        case 0x11:  self = .uint64
        case 0x12:  self = .int64
        case 0x13:  self = .decimal128
        case 0xFF:  self = .min
        case 0x7F:  self = .max
        default:    return nil
        }
    }
}

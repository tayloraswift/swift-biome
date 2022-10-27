import BSONTraversal

extension BSON
{
    public
    enum BinarySubtypeError:Error
    {
        case missing
        case invalid(UInt8)
    }

    @frozen public 
    struct BinarySubtype:RawRepresentable
    {
        public static let generic:Self     = .init(unchecked: 0x00)
        public static let function:Self    = .init(unchecked: 0x01)
        public static let uuid:Self        = .init(unchecked: 0x04)
        public static let md5:Self         = .init(unchecked: 0x05)
        public static let encrypted:Self   = .init(unchecked: 0x06)
        public static let compressed:Self  = .init(unchecked: 0x07)
        public static let custom:Self      = .init(unchecked: 0x80)

        public
        let rawValue:UInt8

        private
        init(unchecked code:UInt8)
        {
            self.rawValue = code
        }
        @inlinable public 
        init?(rawValue:UInt8)
        {
            switch rawValue
            {
            case 0x00, 0x02:    self.rawValue = 0x00
            case 0x01:          self.rawValue = 0x01
            case 0x03, 0x04:    self.rawValue = 0x04
            case 0x05:          self.rawValue = 0x05
            case 0x06:          self.rawValue = 0x06
            case 0x07:          self.rawValue = 0x07
            case 0x80 ... 0xFF: self.rawValue = rawValue
            default:            return nil
            }
        }
    }
}

extension BSON
{
    @frozen public
    struct Binary<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        public 
        let bytes:Bytes.SubSequence
        public 
        let subtype:BinarySubtype
    }
}
extension BSON.Binary:TraversableBSON
{
    @inlinable public static
    var headerBytes:Int
    {
        -1
    }
    @inlinable public
    init(_ bytes:Bytes) throws
    {
        guard let subtype:UInt8 = bytes.first
        else
        {
            throw BSON.BinarySubtypeError.missing
        }
        guard let subtype:BSON.BinarySubtype = .init(rawValue: subtype)
        else
        {
            throw BSON.BinarySubtypeError.invalid(subtype)
        }

        self.bytes = bytes.dropFirst()
        self.subtype = subtype
    }
}

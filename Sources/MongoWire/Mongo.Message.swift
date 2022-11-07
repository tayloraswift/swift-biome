import CRC
import BSON

extension Mongo
{
    @frozen public
    struct Message<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        public
        let header:MessageHeader
        public
        let flags:MessageFlags
        public
        let sections:Sections
        public
        let checksum:CRC32?

        @inlinable public
        init(header:MessageHeader, flags:MessageFlags, sections:Sections, checksum:CRC32?)
        {
            self.header = header
            self.flags = flags
            self.sections = sections
            self.checksum = checksum
        }
    }
}
extension Mongo.Message:Sendable where Bytes:Sendable
{
}
extension Mongo.Message
{
    @inlinable public
    var documents:[BSON.Document<Bytes>]
    {
        self.sections.documents
    }
}
extension Mongo.Message:Identifiable
{
    @inlinable public
    var id:Mongo.MessageIdentifier
    {
        self.header.id
    }
}

extension BSON.Input
{
    @inlinable public mutating
    func parse(
        as _:Mongo.Message<Source.SubSequence>.Type = Mongo.Message<Source.SubSequence>.self,
        header:Mongo.MessageHeader) throws -> Mongo.Message<Source.SubSequence>
    {
        let flags:Mongo.MessageFlags = try .init(validating: try self.parse(as: UInt32.self))

        let sections:Mongo.Message<Source.SubSequence>.Sections = try self.parse(
            as: Mongo.Message<Source.SubSequence>.Sections.self)

        let checksum:CRC32? = flags.contains(.checksumPresent) ?
            .init(checksum: try self.parse(as: UInt32.self)) : nil
        
        return .init(header: header, flags: flags, sections: sections, checksum: checksum)
    }
}

extension Mongo.Message
{
    @inlinable public
    init(sections:Sections, checksum:Bool = false, id:Mongo.MessageIdentifier)
    {
        // 4 for size, 4 for flags
        var count:Int = 8
        for section:Sections.Element in sections
        {
            // section type
            count += 1
            switch section
            {
            case .body(let document):
                count += document.size
            
            case .sequence(let documents, id: let id):
                // 4 for size, 1 for null byte after id string
                count += documents.reduce(5 + id.utf8.count) { $0 + $1.size }
            }
        }
        let flags:Mongo.MessageFlags
        let crc32:CRC32?
        if checksum
        {
            count += 4
            flags = [.checksumPresent]
            fatalError("unimplemented")
        }
        else
        {
            flags = []
            crc32 = nil
        }

        self.init(header: .init(count: count, id: id), flags: flags,
            sections: sections,
            checksum: crc32)
    }
}

extension BSON.Output
{
    @inlinable public mutating
    func serialize(message:Mongo.Message<some RandomAccessCollection<UInt8>>)
    {
        self.serialize(header: message.header)
        self.serialize(integer: message.flags.rawValue as UInt32)
        self.serialize(sections: message.sections)
        if let crc32:CRC32 = message.checksum
        {
            self.serialize(integer: crc32.checksum as UInt32)
        }
    }
}

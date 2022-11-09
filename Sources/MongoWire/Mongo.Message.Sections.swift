import BSON

extension Mongo.Message
{
    @frozen public
    struct Sections
    {
        public
        var documents:[BSON.Document<Bytes>]
        public
        var metadata:[ElementMetadata]

        @inlinable public
        init()
        {
            self.documents = []
            self.metadata = []
        }
    }
}
extension Mongo.Message.Sections.Element:Sendable where Bytes:Sendable
{
}
extension Mongo.Message.Sections:Sendable where Bytes:Sendable
{
}
extension Mongo.Message.Sections:RandomAccessCollection
{
    @frozen public
    enum ElementMetadata:Sendable
    {
        case body(Int)
        case sequence(Range<Int>, id:String)
    }
    @frozen public
    enum Element
    {
        case body               (BSON.Document<Bytes>)
        case sequence(ArraySlice<BSON.Document<Bytes>>, id:String)
    }

    @inlinable public
    var startIndex:Int
    {
        self.metadata.startIndex
    }
    @inlinable public
    var endIndex:Int
    {
        self.metadata.endIndex
    }
    @inlinable public
    subscript(index:Int) -> Element
    {
        switch self.metadata[index]
        {
        case .body(let index):
            return .body(self.documents[index])
        
        case .sequence(let indices, id: let id):
            return .sequence(self.documents[indices], id: id)
        }
    }
}
extension Mongo.Message.Sections
{
    /// Creates a section list with a single body section containing a single document.
    @inlinable public
    init(_ document:BSON.Document<Bytes>)
    {
        self.init()
        self.append(body: document)
    }

    @inlinable public mutating
    func append(body document:__owned BSON.Document<Bytes>)
    {
        self.metadata.append(.body(self.documents.endIndex))
        self.documents.append(document)
    }
    @inlinable public mutating
    func append<Source>(sequence:__owned Mongo.Message<Source>.Sequence) throws
        where Source:RandomAccessCollection<UInt8>, Source.SubSequence == Bytes
    {
        var sequence:BSON.Input<Source> = .init(sequence.bytes)

        let id:String = try sequence.parse(as: String.self)
        let start:Int = self.documents.endIndex
        while sequence.index < sequence.source.endIndex
        {
            self.documents.append(try sequence.parse(as: BSON.Document<Bytes>.self))
        }
        self.metadata.append(.sequence(start ..< self.documents.endIndex, id: id))
    }
}

extension BSON.Input
{
    @inlinable public mutating
    func parse(
        as _:Mongo.Message<Source.SubSequence>.Sections.Type = Mongo.Message<Source.SubSequence>.Sections.self)
        throws -> Mongo.Message<Source.SubSequence>.Sections
    {
        var sections:Mongo.Message<Source.SubSequence>.Sections = .init()
        while let section:UInt8 = self.next()
        {
            guard let section:Mongo.MessageSection = .init(rawValue: section)
            else
            {
                throw Mongo.MessageSectionError.init(invalid: section)
            }
            switch section
            {
            case .body:
                    sections.append(body:     try self.parse(
                    as: BSON.Document<Source.SubSequence>.self))
            case .sequence:
                try sections.append(sequence: try self.parse(
                    as: Mongo.Message<Source.SubSequence>.Sequence.self))
            }
        }
        return sections
    }
}

extension BSON.Output
{
    @inlinable public mutating
    func serialize<Bytes>(sections:Mongo.Message<Bytes>.Sections)
    {
        for section:Mongo.Message<Bytes>.Sections.Element in sections
        {
            switch section
            {
            case .body(let document):
                self.append(Mongo.MessageSection.body.rawValue)
                self.serialize(document: document)
            
            case .sequence(let documents, id: let id):
                self.append(Mongo.MessageSection.sequence.rawValue)
                // TODO: get rid of this intermediate buffer
                let sequence:Mongo.Message<[UInt8]>.Sequence = .init(id: id,
                    documents: documents)
                self.serialize(integer: sequence.header as Int32)
                self.append(sequence.bytes)
            }
        }
    }
}

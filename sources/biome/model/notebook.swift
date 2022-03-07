@frozen public 
struct NotebookStorage
{
    public 
    var utf8:[UInt8]
    
    @inlinable public 
    init(utf8:[UInt8])
    {
        self.utf8 = utf8
    }
    
    @inlinable public
    func load<Highlight>(element:UInt64, at index:inout Int) -> (text:String, highlight:Highlight)
        where Highlight:RawRepresentable, Highlight.RawValue == UInt8
    {
        withUnsafeBytes(of: element)
        {
            let flags:UInt8 = $0[$0.endIndex - 1]
            guard let highlight:Highlight = .init(rawValue: flags & 0b0111_1111)
            else 
            {
                fatalError("could not round-trip raw value '\(flags & 0b0111_1111)'")
            }
            if  flags & 0b1000_0000 != 0 
            {
                // inline UTF-8
                return (String.init(decoding: $0.dropLast().prefix { $0 != 0 }, as: Unicode.UTF8.self), highlight)
            }
            else 
            {
                // indirectly-allocated UTF-8
                let next:Int = Int.init($0.load(as: UInt32.self))
                let utf8:ArraySlice<UInt8> = self.utf8[index ..< next]
                index = next 
                return (String.init(decoding: utf8, as: Unicode.UTF8.self), highlight)
            }
        }
    }
    @inlinable public mutating 
    func store<Highlight>(text:String, highlight:Highlight) -> UInt64
        where Highlight:RawRepresentable, Highlight.RawValue == UInt8
    {
        var text:String = text
        return text.withUTF8 
        {
            (utf8:UnsafeBufferPointer<UInt8>) in 
            var element:UInt64 = 0 
            withUnsafeMutableBytes(of: &element)
            {
                if utf8.count < $0.count 
                {
                    $0.copyBytes(from: utf8)
                    $0[$0.endIndex - 1] = 0x80 | highlight.rawValue 
                }
                else 
                {
                    self.utf8.append(contentsOf: utf8)
                    $0.storeBytes(of: UInt32.init(self.utf8.endIndex), as: UInt32.self)
                    $0[$0.endIndex - 1] =        highlight.rawValue 
                }
            }
            return element
        }
    }
}
@frozen public 
struct NotebookContent<Highlight>:Sequence where Highlight:RawRepresentable, Highlight.RawValue == UInt8
{
    public 
    var storage:NotebookStorage
    public 
    var elements:[UInt64]
    
    @inlinable public 
    init()
    {
        self.storage    = .init(utf8: [])
        self.elements   = []
    }
    @inlinable public 
    init(capacity:Int)
    {
        self.init()
        self.elements.reserveCapacity(capacity)
    }
    
    @inlinable public mutating 
    func append(text:String, highlight:Highlight)
    {
        self.elements.append(self.storage.store(text: text, highlight: highlight))
    }
    
    @inlinable public
    var underestimatedCount:Int 
    {
        self.elements.count
    }
    
    @inlinable public 
    func makeIterator() -> Iterator 
    {
        .init(self.storage, elements: self.elements)
    }
    
    @frozen public 
    struct Iterator:IteratorProtocol 
    {
        public 
        let storage:NotebookStorage, 
            elements:[UInt64]
        public 
        var storageIndex:Int, 
            elementIndex:Int
        
        @inlinable public 
        init(_ storage:NotebookStorage, elements:[UInt64])
        {
            self.storage        = storage 
            self.elements       = elements
            self.storageIndex   = self.storage.utf8.startIndex
            self.elementIndex   = self.elements.startIndex
        }
        
        @inlinable public mutating 
        func next() -> (text:String, highlight:Highlight)?
        {
            guard self.elementIndex < self.elements.endIndex 
            else 
            {
                return nil 
            }
            let element:UInt64 = self.elements[self.elementIndex]
            self.elementIndex += 1
            return self.storage.load(element: element, at: &self.storageIndex)
        }
    }
}

@frozen public 
struct Notebook<Highlight, Link>:Sequence where Highlight:RawRepresentable, Highlight.RawValue == UInt8
{
    @frozen public 
    struct Iterator:IteratorProtocol 
    {
        public 
        var link:(index:Int, target:Link)?
        public 
        var links:Array<(index:Int, target:Link)>.Iterator, 
            content:NotebookContent<Highlight>.Iterator 
        
        @inlinable public 
        init(_ content:NotebookContent<Highlight>, links:[(index:Int, target:Link)])
        {
            self.content    = content.makeIterator() 
            self.links      = links.makeIterator()
            self.link       = self.links.next()
        }
        
        @inlinable public mutating 
        func next() -> (text:String, highlight:Highlight, link:Link?)?
        {
            let current:Int = self.content.elementIndex
            guard let (text, highlight):(String, Highlight) = self.content.next() 
            else 
            {
                return nil 
            }
            if let (index, target):(Int, Link) = self.link, index == current 
            {
                self.link = self.links.next()
                return (text, highlight, target)
            }
            else 
            {
                return (text, highlight, nil)
            }
        }
    }
    
    public 
    var content:NotebookContent<Highlight>
    public 
    var links:[(index:Int, target:Link)]
    
    @inlinable public
    var underestimatedCount:Int 
    {
        self.content.underestimatedCount
    }
    
    @inlinable public 
    func makeIterator() -> Iterator 
    {
        .init(self.content, links: self.links)
    }
    
    @inlinable public 
    init(capacity:Int)
    {
        self.init(content: .init(capacity: capacity), links: [])
    }
    @inlinable public 
    init(content:NotebookContent<Highlight>, links:[(index:Int, target:Link)])
    {
        self.content    = content 
        self.links      = links
    }

    @inlinable public 
    init<S>(_ segments:S) where S:Sequence, S.Element == (String, Highlight, Link?)
    {
        self.init(capacity: segments.underestimatedCount)
        for (text, highlight, link):(String, Highlight, Link?) in segments
        {
            if let link:Link = link 
            {
                self.links.append((self.content.elements.endIndex, link))
            }
            self.content.append(text: text, highlight: highlight)
        }
    }
    @inlinable public 
    init<S>(_ segments:S) where S:Sequence, S.Element == (String, Highlight)
    {
        self.init(capacity: segments.underestimatedCount)
        for (text, highlight):(String, Highlight) in segments
        {
            self.content.append(text: text, highlight: highlight)
        }
    }
    
    @inlinable public 
    func mapLinks<T>(_ transform:(Link) throws -> T) rethrows -> Notebook<Highlight, T>
    {
        .init(content: self.content, links: try self.links.map
        {
            ($0.index, try transform($0.target))
        })
    }
    @inlinable public 
    func compactMapLinks<T>(_ transform:(Link) throws -> T?) rethrows -> Notebook<Highlight, T>
    {
        .init(content: self.content, links: try self.links.compactMap
        {
            if let transformed:T = try transform($0.target)
            {
                return ($0.index, transformed)
            }
            else 
            {
                return nil 
            }
        })
    }
}

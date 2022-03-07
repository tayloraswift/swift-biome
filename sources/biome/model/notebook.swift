@frozen public 
struct Notebook<Highlight, Link> where Highlight:RawRepresentable, Highlight.RawValue == UInt8
{
    public 
    var slab:[UInt8]
    public 
    var elements:[UInt64]
    public 
    var links:[(index:Int, target:Link)]
    
    @inlinable public 
    init(slab:[UInt8] = [], elements:[UInt64] = [], links:[(index:Int, target:Link)] = [])
    {
        self.slab = slab
        self.links = links
        self.elements = elements
    }

    init<S>(_ segments:S) 
        where S:Sequence, S.Element == (String, Highlight, Link?)
    {
        self.init()
        self.elements.reserveCapacity(segments.underestimatedCount)
        for (text, highlight, link):(String, Highlight, Link?) in segments
        {
            self.append(text, highlighted: highlight, link: link)
        }
    }
    
    @inlinable public mutating 
    func append(_ text:String, highlighted highlight:Highlight, link:Link?)
    {
        var text:String = text
        let next:UInt64 = text.withUTF8 
        {
            (utf8:UnsafeBufferPointer<UInt8>) in 
            var slug:UInt64 = 0 
            withUnsafeMutableBytes(of: &slug)
            {
                if utf8.count < $0.count 
                {
                    $0.copyBytes(from: utf8)
                    $0[$0.endIndex - 1] = 0x80 | highlight.rawValue 
                }
                else 
                {
                    self.slab.append(contentsOf: utf8)
                    $0.storeBytes(of: UInt32.init(self.slab.endIndex), as: UInt32.self)
                    $0[$0.endIndex - 1] =        highlight.rawValue 
                }
            }
            return slug
        }
        if let link:Link = link 
        {
            self.links.append((self.elements.endIndex, link))
        }
        self.elements.append(next)
    }
    
    @inlinable public 
    func map<T>(_ transform:(_ text:String, _ highlight:Highlight, _ link:Link?) throws -> T) rethrows -> [T]
    {
        var transformed:[T]     = []
            transformed.reserveCapacity(self.elements.count)
        var slabIndex:Int       = self.slab.startIndex, 
            elementIndex:Int    = self.elements.startIndex 
            
        for link:(index:Int, target:Link) in self.links 
        {
            for index:Int in elementIndex ..< link.index
            {
                let (text, highlight):(String, Highlight) = self.element(at: index, slab: &slabIndex)
                transformed.append(try transform(text, highlight, nil))
            }
            let (text, highlight):(String, Highlight) = self.element(at: link.index, slab: &slabIndex)
            transformed.append(try transform(text, highlight, link.target))
            elementIndex = link.index + 1
        }
        for index:Int in elementIndex ..< self.elements.endIndex
        {
            let (text, highlight):(String, Highlight) = self.element(at: index, slab: &slabIndex)
            transformed.append(try transform(text, highlight, nil))
        }
        return transformed
    }
    @inlinable public 
    func compactMap<T>(_ transform:(_ text:String, _ highlight:Highlight, _ link:Link?) throws -> T?) rethrows -> [T]
    {
        var transformed:[T]     = []
        var slabIndex:Int       = self.slab.startIndex, 
            elementIndex:Int    = self.elements.startIndex 
        for link:(index:Int, target:Link) in self.links 
        {
            for index:Int in elementIndex ..< link.index
            {
                let (text, highlight):(String, Highlight) = self.element(at: index, slab: &slabIndex)
                if let value:T = try transform(text, highlight, nil)
                {
                    transformed.append(value)
                }
            }
            let (text, highlight):(String, Highlight) = self.element(at: link.index, slab: &slabIndex)
            if let value:T = try transform(text, highlight, link.target)
            {
                transformed.append(value)
            }
            elementIndex = link.index + 1
        }
        for index:Int in elementIndex ..< self.elements.endIndex
        {
            let (text, highlight):(String, Highlight) = self.element(at: index, slab: &slabIndex)
            if let value:T = try transform(text, highlight, nil)
            {
                transformed.append(value)
            }
        }
        return transformed
    }
    
    @inlinable public 
    func compactMapLinks<T>(_ transform:(Link) throws -> T?) rethrows -> Notebook<Highlight, T>
    {
        .init(slab: self.slab, elements: self.elements, links: try self.links.compactMap
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
    
    @inlinable public 
    func element(at index:Int, slab:inout Int) -> (text:String, highlight:Highlight)
    {
        withUnsafeBytes(of: self.elements[index])
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
                return (String.init(decoding: $0.dropLast(), as: Unicode.UTF8.self), highlight)
            }
            else 
            {
                // indirectly-allocated UTF-8
                let next:Int = Int.init($0.load(as: UInt32.self))
                let utf8:ArraySlice<UInt8> = self.slab[slab ..< next]
                slab = next 
                return (String.init(decoding: utf8, as: Unicode.UTF8.self), highlight)
            }
        }
    }
}

extension Notebook where Link == Never 
{
    @inlinable public 
    init<S>(_ segments:S) where S:Sequence, S.Element == (String, Highlight)
    {
        self.init()
        self.elements.reserveCapacity(segments.underestimatedCount)
        for (text, highlight):(String, Highlight) in segments
        {
            self.append(text, highlighted: highlight, link: nil)
        }
    }
    @inlinable public 
    func map<T>(_ transform:(_ text:String, _ highlight:Highlight) throws -> T) rethrows -> [T]
    {
        try self.map 
        {
            (text:String, highlight:Highlight, _:Link?) in 
            try transform(text, highlight)
        }
    }
    @inlinable public 
    func compactMap<T>(_ transform:(_ text:String, _ highlight:Highlight) throws -> T?) rethrows -> [T]
    {
        try self.compactMap 
        {
            (text:String, highlight:Highlight, _:Link?) in 
            try transform(text, highlight)
        }
    }
}

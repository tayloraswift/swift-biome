protocol CulturalIndex 
{
    associatedtype Culture 
    
    init(_ culture:Culture, offset:Int)
    var offset:Int { get }
}

struct CulturalBuffer<Index, Element> where Index:CulturalIndex, Element:Identifiable
{
    private 
    var storage:[Element] 
    private(set)
    var indices:[Element.ID: Index]
    
    var all:[Element]
    {
        _read 
        {
            yield self.storage
        }
    }
    
    init() 
    {
        self.storage = []
        self.indices = [:]
    }
    
    // in general we use ``count`` and not `endIndex` because cultural indices 
    // are defined in terms of offsets ...
    var count:Int 
    {
        self.storage.count
    }
    
    subscript(local index:Index) -> Element
    {
        _read 
        {
            yield  self.storage[index.offset]
        }
        _modify
        {
            yield &self.storage[index.offset]
        }
    }
    
    mutating 
    func insert(_ id:Element.ID, culture:Index.Culture, 
        _ create:(Element.ID, Index) throws -> Element) rethrows -> Index 
    {
        if let index:Index = self.indices[id]
        {
            return index 
        }
        else 
        {
            // create records for elements if they do not yet exist 
            let index:Index = .init(culture, offset: self.count)
            self.storage.append(try create(id, index))
            self.indices[id] = index
            return index 
        }
    }
}

struct Path:Equatable, RandomAccessCollection, CustomStringConvertible, Sendable
{
    var prefix:[String]
    var last:String
    
    var startIndex:Int 
    {
        self.prefix.startIndex
    }
    var endIndex:Int 
    {
        self.prefix.endIndex + 1
    }
    subscript(index:Int) -> String
    {
        _read 
        {
            if index == self.prefix.endIndex 
            {
                yield self.last 
            }
            else 
            {
                yield self.prefix[index]
            }
        }
        _modify 
        {
            if index == self.prefix.endIndex 
            {
                yield &self.last 
            }
            else 
            {
                yield &self.prefix[index]
            }
        }
    }
    
    init(prefix:[String] = [], last:String)
    {
        self.last = last
        self.prefix = prefix 
    }
    
    init?<Components>(_ components:Components) 
        where Components:BidirectionalCollection, Components.Element == String
    {
        guard let last:String = components.last 
        else 
        {
            return nil 
        }
        self.last = last 
        self.prefix = .init(components.dropLast())
    }
    
    var description:String 
    {
        self.joined(separator: ".")
    }
}

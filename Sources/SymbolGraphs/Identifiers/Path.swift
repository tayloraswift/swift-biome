import JSON

@frozen public
struct Path:Equatable, RandomAccessCollection, CustomStringConvertible, Sendable
{
    public 
    var prefix:[String]
    public 
    var last:String
    
    @inlinable public
    var startIndex:Int 
    {
        self.prefix.startIndex
    }
    @inlinable public
    var endIndex:Int 
    {
        self.prefix.endIndex + 1
    }
    @inlinable public
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
    @inlinable public
    init(prefix:[String] = [], last:String)
    {
        self.last = last
        self.prefix = prefix 
    }
    
    @inlinable public
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
    
    @inlinable public
    var description:String 
    {
        self.joined(separator: ".")
    }
}

extension Path 
{
    init(from json:JSON) throws
    {
        let components:[JSON] = try json.as([JSON].self) { $0 > 0 }
        let last:Int = components.index(before: components.endIndex)
        self.init(
            prefix: try components[..<last].map { try $0.as(String.self) }, 
            last: try components.load(last, as: String.self))
    }
}
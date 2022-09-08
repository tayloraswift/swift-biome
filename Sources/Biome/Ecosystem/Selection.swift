enum SelectionError<Element>:Error 
{
    case none
    case many([Element])
}
enum _Selection<Element>
{
    // we have to absorb the optional, because this type is 
    // generic, and we cannot vend an extension on an optional generic type.

    case none 
    case one(Element)
    case many([Element])
            
    init(_ elements:[Element]) 
    {
        if let first:Element = elements.first 
        {
            self = elements.count < 2 ? .one(first) : .many(elements)
        }
        else 
        {
            self = .none
        }
    }
    
    func unique() throws -> Element
    {
        switch self 
        {
        case .none: 
            throw SelectionError<Element>.none
        case .one(let element):
            return element
        case .many(let elements): 
            throw SelectionError<Element>.many(elements)
        }
    }

    mutating 
    func append(_ element:Element) 
    {
        switch _move self 
        {
        case .none: 
            self = .one(element)
        case .one(let first): 
            self = .many([first, element])
        case .many(var elements): 
            elements.append(element)
            self = .many(elements)
        }
    }
}

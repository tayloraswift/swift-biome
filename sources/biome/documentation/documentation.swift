import StructuredDocument
import HTML

public
enum Documentation 
{
    typealias Element = HTML.Element<Anchor>
    typealias StaticElement = HTML.Element<Never>
    
    public 
    enum Channel:Hashable, Sendable 
    {
        case package
        case module
        case symbol 
        case article
    }
}

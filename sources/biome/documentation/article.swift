import StructuredDocument 
import HTML

enum ArticleError:Error 
{
    case emptyImageSource
    case emptyLinkDestination
    
    case ambiguousSymbolReference(Documentation.UnresolvedLink)
    case undefinedSymbolReference(Documentation.UnresolvedLink)
    
    case unsupportedMarkdown(String)
    
    // TODO: rework these
    case unsupportedMagicKeywords([String]) 
    
    case emptyReturnsField
    case emptyParameterField(name:String?) 
    case emptyParameterList
    
    case multipleReturnsFields([Article<Documentation.UnresolvedLink>.Element], [Article<Documentation.UnresolvedLink>.Element])
    
    case invalidParameterListItem(Article<Documentation.UnresolvedLink>.Element)
    case invalidParameterList(Article<Documentation.UnresolvedLink>.Element)
    case multipleParameterLists(Article<Documentation.UnresolvedLink>.Element, Article<Documentation.UnresolvedLink>.Element)
    
    /* var description:String 
    {
        switch self 
        {
        case .empty(parameter: nil):
            return "comment 'parameters' is completely empty"
        case .empty(parameter: let name?):
            return "comment 'parameter \(name)' is completely empty"
        case .invalidListItem(let item):
            return 
                """
                comment 'parameters' contains invalid list item:
                '''
                \(item.rendered)
                '''
                """
        case .invalidList(let block):
            return 
                """
                comment 'parameters' must contain a list, encountered:
                '''
                \(block.rendered)
                '''
                """
        case .multipleLists(let blocks):
            return 
                """
                comment 'parameters' must contain exactly one list, encountered:
                '''
                \(blocks.map(\.rendered).joined(separator: "\n"))
                '''
                """
        }
    } */
}
public
struct Article<Anchor>:GreenAlien where Anchor:Hashable
{
    typealias Element = HTML.Element<Anchor> 
    
    struct Content
    {
        typealias Element = HTML.Element<Anchor> 
        
        var errors:[Error]
        let summary:DocumentTemplate<Anchor, [UInt8]>?
        let discussion:DocumentTemplate<Anchor, [UInt8]>?
        
        static 
        var empty:Self 
        {
            .init(errors: [], summary: nil, discussion: nil)
        }
        
        func compactMapAnchors<T>(_ transform:(Anchor) throws -> T?) rethrows -> Article<T>.Content
            where T:Hashable
        {
            .init(errors:   self.errors, 
                summary:    try self.summary?.compactMap(transform), 
                discussion: try self.discussion?.compactMap(transform))
        }
    }
    
    public
    let title:String, 
        path:[String]
    public 
    let snippet:String
    let headline:Documentation.Element?
    var content:Content
    
    var stem:[[UInt8]]
    {
        //self.path.map { URI.encode(component: $0.utf8) }
        self.path.suffix(1).map { Documentation.URI.encode(component: $0.utf8) }
    }
    var leaf:[UInt8]
    {
        []
    }
}
extension Article.Content where Anchor == Documentation.UnresolvedLink
{    
    init(errors:[Error], summary:Element?, discussion:[Element]) 
    {
        self.errors = errors
        self.summary = summary.map(DocumentTemplate<Anchor, [UInt8]>.init(freezing:))
        self.discussion = discussion.isEmpty ? nil : .init(freezing: discussion)
    }
}

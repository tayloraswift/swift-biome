import StructuredDocument 
import HTML 

extension Documentation 
{
    enum ArticleError:Error 
    {
        case emptyImageSource
        case emptyLinkDestination
        
        case ambiguousSymbolLink(URI.Path, overload:Int?)
        case undefinedSymbolLink(URI.Path, overload:Int?)
        case unsupportedMarkdown(String)
        
        case invalidDocCSymbolLinkSuffix(String)
    }
    
    enum CommentError:Error 
    {
        case unsupportedMagicKeywords([String]) 
        
        case emptyReturnsField
        case emptyParameterField(name:String?) 
        case emptyParameterList
        
        case multipleReturnsFields([HTML.Element<Never>], [HTML.Element<Never>])
        
        case invalidParameterListItem(HTML.Element<Never>)
        case invalidParameterList(HTML.Element<Never>)
        case multipleParameterLists(HTML.Element<Never>, HTML.Element<Never>)
        
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
}

import Markdown
import StructuredDocument 
import HTML 

extension Biome 
{
    enum ArticleReturnsError:Error 
    {
        case empty 
        case duplicate(section:[HTML.Element<Anchor>])
    }
    enum ArticleParametersError:Error, CustomStringConvertible
    {
        case empty(parameter:String?) 
        
        case invalidListItem(HTML.Element<Anchor>)
        case invalidList(HTML.Element<Anchor>)
        case multipleLists([HTML.Element<Anchor>])
        
        var description:String 
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
        }
    }
    enum ArticleContentError:Error 
    {
        case unsupported(markup:Markdown.Markup)
        case missingImageSource
        case missingLinkDestination
    }
    enum ArticleSymbolLinkError:Error 
    {
        case empty
    }
    enum ArticleAsideError:Error 
    {
        case undefined(keywords:[String]) 
    }
}

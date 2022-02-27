import Markdown
import StructuredDocument 
import HTML 

extension Biome 
{
    enum ArticleReturnsError:Error 
    {
        case empty 
        case duplicate(section:[Frontend])
    }
    enum ArticleParametersError:Error 
    {
        case empty(parameter:String?) 
        
        case invalid(section:Frontend)
        case duplicate(section:Frontend)
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

import StructuredDocument 
import HTML

extension Documentation 
{
    typealias ArticleElement = HTML.Element<Documentation.Index>
    
    struct Comment 
    {
        enum MagicListItem 
        {
            case parameters([(name:String, comment:[ArticleElement])])
            case returns([ArticleElement])
            case aside(ArticleElement)
        }
        
        var errors:[Error]
        
        private 
        var baked:
        (
            summary:String?, 
            discussion:String?
        )
        
        init() 
        {
            self.baked = (nil, nil)
            self.errors = []
        }
        
        var summary:Element?
        {
            self.baked.summary.map(Element.text(escaped:))
        }
        var discussion:Element?
        {
            self.baked.discussion.map(Element.text(escaped:))
        }
        
        mutating 
        func update(summary:ArticleElement?, discussion toplevel:[ArticleElement], errors:[Error])
        {
            self.errors         = errors
            self.baked.summary  = summary?.rendered
            
            var parameters:[(name:String, comment:[ArticleElement])] = []
            var returns:[ArticleElement]      = []
            var discussion:[ArticleElement]   = []
            for block:ArticleElement in toplevel 
            {
                // filter out top-level ‘ul’ blocks, since they may be special 
                guard case .container(.ul, id: let id, attributes: let attributes, content: let items) = block 
                else 
                {
                    discussion.append(block)
                    continue 
                }
                
                var ignored:[ArticleElement] = []
                listitems:
                for item:ArticleElement in items
                {
                    guard case .container(.li, id: _, attributes: _, content: let content) = item 
                    else 
                    {
                        fatalError("unreachable")
                    }
                    do 
                    {
                        switch try Comment.magic(item: content)
                        {
                        case nil:
                            ignored.append(item)
                            continue 
                            
                        case .parameters(let group):
                            parameters.append(contentsOf: group)
                        case .returns(let section):
                            if returns.isEmpty 
                            {
                                returns = section
                            }
                            else 
                            {
                                throw CommentError.multipleReturnsFields(returns, section)
                            }
                        case .aside(let section):
                            discussion.append(section)
                        }
                        
                        continue listitems
                    }
                    catch let error 
                    {
                        self.errors.append(error)
                    }
                    
                    ignored.append(item)
                }
                guard ignored.isEmpty 
                else 
                {
                    discussion.append(.container(.ul, id: id, attributes: attributes, content: ignored))
                    continue 
                }
            }
            
            var sections:[ArticleElement] = []
            if !parameters.isEmpty
            {
                sections.append(Self.section(parameters: parameters))
            }
            if !returns.isEmpty
            {
                sections.append(Self.section(returns, heading: "Returns",  class: "returns"))
            }
            if !discussion.isEmpty
            {
                sections.append(Self.section(discussion, heading: "Overview", class: "discussion"))
            }
            
            self.baked.discussion = sections.isEmpty ? nil : sections.map(\.rendered).joined()
        }
        
        private static 
        func section(_ content:[ArticleElement], heading:String, class:String) -> ArticleElement
        {
            ArticleElement[.section]
            {
                [`class`]
            }
            content: 
            {
                ArticleElement[.h2]
                {
                    heading
                }
                content
            }
        }
        private static 
        func section(parameters:[(name:String, comment:[ArticleElement])]) -> ArticleElement
        {
            ArticleElement[.section]
            {
                ["parameters"]
            }
            content: 
            {
                ArticleElement[.h2]
                {
                    "Parameters"
                }
                ArticleElement[.dl]
                {
                    for (name, comment):(String, [ArticleElement]) in parameters 
                    {
                        ArticleElement[.dt]
                        {
                            name
                        }
                        ArticleElement[.dd]
                        {
                            comment
                        }
                    }
                }
            }
        }
        
        static 
        func magic(item:[ArticleElement]) throws -> MagicListItem?
        {
            guard let (keywords, content):([String], [ArticleElement]) = Self.keywords(prefixing: item)
            else 
            {
                return nil 
            }
            // `keywords` always contains at least one keyword
            let keyword:String = keywords[0]
            switch keyword
            {
            case "parameters": 
                guard keywords.count == 1 
                else 
                {
                    throw CommentError.unsupportedMagicKeywords(keywords)
                }
                return .parameters(try Self.parameters(in: content))
                
            case "parameter": 
                guard keywords.count == 2 
                else 
                {
                    throw CommentError.unsupportedMagicKeywords(keywords)
                }
                let name:String = keywords[1]
                if content.isEmpty
                {
                    throw CommentError.emptyParameterField(name: name)
                } 
                return .parameters([(name, content)])
            
            case "returns":
                guard keywords.count == 1 
                else 
                {
                    throw CommentError.unsupportedMagicKeywords(keywords)
                }
                if content.isEmpty
                {
                    throw CommentError.emptyReturnsField
                }
                return .returns(content)
            
            case "tip", "note", "info", "warning", "throws", "important", "precondition", "complexity":
                guard keywords.count == 1 
                else 
                {
                    throw CommentError.unsupportedMagicKeywords(keywords)
                }
                return .aside(ArticleElement[.aside]
                {
                    [keyword]
                }
                content:
                {
                    ArticleElement[.h2]
                    {
                        keyword
                    }
                    
                    content
                })
                
            default:
                throw CommentError.unsupportedMagicKeywords(keywords)
            }
        }
        
        private static
        func parameters(in content:[ArticleElement]) throws -> [(name:String, comment:[ArticleElement])]
        {
            guard let first:ArticleElement = content.first 
            else 
            {
                throw CommentError.emptyParameterList
            }
            // look for a nested list 
            guard case .container(.ul, id: _, attributes: _, content: let items) = first 
            else 
            {
                throw CommentError.invalidParameterList(first)
            }
            if let second:ArticleElement = content.dropFirst().first
            {
                throw CommentError.multipleParameterLists(first, second)
            }
            
            var parameters:[(name:String, comment:[ArticleElement])] = []
            for item:ArticleElement in items
            {
                guard   case .container(.li, id: _, attributes: _, content: let content) = item, 
                        let (keywords, content):([String], [ArticleElement]) = Self.keywords(prefixing: content), 
                        let name:String = keywords.first, keywords.count == 1
                else 
                {
                    throw CommentError.invalidParameterListItem(item)
                }
                parameters.append((name, content))
            }
            return parameters
        }
        
        private static
        func keywords(prefixing content:[ArticleElement]) -> (keywords:[String], trimmed:[ArticleElement])?
        {
            //  p 
            //  {
            //      text 
            //      {
            //          " foo  bar:  "
            //      }
            //      ...
            //  }
            //  ...
            guard   case .container(.p, id: let id, attributes: let attributes, content: var inline)? = content.first, 
                    let first:ArticleElement = inline.first 
            else 
            {
                return nil
            }
            let keywords:Substring
            switch first 
            {
            case .text(escaped: let string):
                guard let colon:String.Index = string.firstIndex(of: ":")
                else 
                {
                    return nil
                }
                let remaining:Substring = string[colon...].dropFirst().drop(while: \.isWhitespace)
                if  remaining.isEmpty 
                {
                    inline.removeFirst()
                }
                else 
                {
                    inline[0] = .text(escaped: String.init(remaining))
                }
                keywords = string[..<colon]
            
            // failing example here: https://developer.apple.com/documentation/system/filedescriptor/duplicate(as:retryoninterrupt:)
            // apple docs just drop the parameter
            case .container(let type, id: _, attributes: _, content: let styled):
                switch type 
                {
                case .code, .strong, .em: 
                    break 
                default: 
                    return nil
                }
                guard   case .text(escaped: let prefix)? = styled.first, styled.count == 1,
                        case .text(escaped: let string)? = inline.dropFirst().first, 
                        let colon:String.Index = string.firstIndex(of: ":"), 
                        string[..<colon].allSatisfy(\.isWhitespace)
                else 
                {
                    return nil
                }
                let remaining:Substring = string[colon...].dropFirst().drop(while: \.isWhitespace)
                if  remaining.isEmpty 
                {
                    inline.removeFirst(2)
                }
                else 
                {
                    inline.removeFirst(1)
                    inline[0] = .text(escaped: String.init(remaining))
                }
                keywords = prefix[...]
            default: 
                return nil
            }
            guard let keywords:[String] = Self.keywords(parsing: keywords)
            else 
            {
                return nil
            }
            
            if inline.isEmpty 
            {
                return (keywords, [ArticleElement].init(content.dropFirst()))
            }
            else 
            {
                var content:[ArticleElement] = content
                    content[0] = .container(.p, id: id, attributes: attributes, content: inline)
                return (keywords, content)
            }
        }
        private static 
        func keywords(parsing string:Substring) -> [String]?
        {
            let keywords:[Substring] = string.split(whereSeparator: \.isWhitespace)
            guard 1 ... 8 ~= keywords.count
            else 
            {
                return nil 
            }
            return keywords.map { $0.lowercased() }
        }
    }
    
    enum ArticleOwner 
    {
        case free(title:String)
        case module(summary:ArticleElement?, index:Int)
        case symbol(summary:ArticleElement?, index:Int) 
    }
    struct Article 
    {
        let namespace:Int
        let path:[[UInt8]]
        let title:String
        let content:[DocumentTemplate<Documentation.Index, [UInt8]>]
        init<S>(namespace:Int, path:S, title:String, content:[ArticleElement])
            where S:Sequence, S.Element:StringProtocol
        {
            self.namespace  = namespace
            self.path       = path.map{ URI.encode(component: $0.utf8) }
            self.title      = title
            self.content    = content.map { $0.template(of: [UInt8].self) }
        }
    }
}

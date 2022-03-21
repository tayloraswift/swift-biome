import StructuredDocument 
import HTML

extension Documentation 
{
    struct Comment<Anchor> where Anchor:Hashable
    {
        typealias Element = HTML.Element<Anchor>
        
        var errors:[Error]
        var summary:DocumentTemplate<Anchor, [UInt8]>?, 
            discussion:DocumentTemplate<Anchor, [UInt8]>?
        
        static 
        var empty:Self 
        {
            .init(errors: [], summary: nil, discussion: nil)
        }
        
        private
        init(errors:[Error], 
            summary:DocumentTemplate<Anchor, [UInt8]>?, 
            discussion:DocumentTemplate<Anchor, [UInt8]>?) 
        {
            self.errors = errors
            self.summary = summary
            self.discussion = discussion
        }

    }
}
extension Documentation.Comment 
{
    // we really need to start using `mapAnchors` instead
    func compactMapAnchors<T>(_ transform:(Anchor) throws -> T?) rethrows -> Documentation.Comment<T> 
        where T:Hashable
    {
        .init(errors: self.errors, 
            summary: try self.summary?.compactMap(transform), 
            discussion: try self.discussion?.compactMap(transform))
    }
}
// need the constraint or it won’t work with error reporting
extension Documentation.Comment where Anchor == Documentation.UnresolvedLink
{    
    init(errors:[Error], summary:Element?, discussion:[Element]) 
    {
        self.errors = errors
        self.summary = summary.map(DocumentTemplate<Anchor, [UInt8]>.init(freezing:))
        self.discussion = discussion.isEmpty ? nil : .init(freezing: Self._sift(discussion, errors: &self.errors))
    }
    
    private 
    enum MagicListItem 
    {
        case parameters([(name:String, comment:[Element])])
        case returns([Element])
        case aside(Element)
    }
    
    private static 
    func _sift(_ toplevel:[Element], errors:inout [Error]) -> [Element]
    {
        var parameters:[(name:String, comment:[Element])] = []
        var returns:[Element]      = []
        var discussion:[Element]   = []
        for block:Element in toplevel 
        {
            // filter out top-level ‘ul’ blocks, since they may be special 
            guard case .container(.ul, attributes: let attributes, content: let items) = block 
            else 
            {
                discussion.append(block)
                continue 
            }
            
            var ignored:[Element] = []
            listitems:
            for item:Element in items
            {
                guard case .container(.li, attributes: _, content: let content) = item 
                else 
                {
                    fatalError("unreachable")
                }
                do 
                {
                    switch try Self.magic(item: content)
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
                            throw Documentation.CommentError.multipleReturnsFields(returns, section)
                        }
                    case .aside(let section):
                        discussion.append(section)
                    }
                    
                    continue listitems
                }
                catch let error 
                {
                    errors.append(error)
                }
                
                ignored.append(item)
            }
            guard ignored.isEmpty 
            else 
            {
                discussion.append(.container(.ul, attributes: attributes, content: ignored))
                continue 
            }
        }
        
        var sections:[Element] = []
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
        
        return sections
    }
    
    private static 
    func section(_ content:[Element], heading:String, class:String) -> Element
    {
        Element[.section]
        {
            [`class`]
        }
        content: 
        {
            Element[.h2]
            {
                heading
            }
            content
        }
    }
    private static 
    func section(parameters:[(name:String, comment:[Element])]) -> Element
    {
        Element[.section]
        {
            ["parameters"]
        }
        content: 
        {
            Element[.h2]
            {
                "Parameters"
            }
            Element[.dl]
            {
                parameters.flatMap 
                {
                    (parameter:(name:String, comment:[Element])) in 
                    [
                        Element[.dt]
                        {
                            parameter.name
                        },
                        Element[.dd]
                        {
                            parameter.comment
                        },
                    ]
                }
            }
        }
    }
    
    private static 
    func magic(item:[Element]) throws -> MagicListItem?
    {
        guard let (keywords, content):([String], [Element]) = Self.keywords(prefixing: item)
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
                throw Documentation.CommentError.unsupportedMagicKeywords(keywords)
            }
            return .parameters(try Self.parameters(in: content))
            
        case "parameter": 
            guard keywords.count == 2 
            else 
            {
                throw Documentation.CommentError.unsupportedMagicKeywords(keywords)
            }
            let name:String = keywords[1]
            if content.isEmpty
            {
                throw Documentation.CommentError.emptyParameterField(name: name)
            } 
            return .parameters([(name, content)])
        
        case "returns":
            guard keywords.count == 1 
            else 
            {
                throw Documentation.CommentError.unsupportedMagicKeywords(keywords)
            }
            if content.isEmpty
            {
                throw Documentation.CommentError.emptyReturnsField
            }
            return .returns(content)
        
        case "tip", "note", "info", "warning", "throws", "important", "precondition", "complexity":
            guard keywords.count == 1 
            else 
            {
                throw Documentation.CommentError.unsupportedMagicKeywords(keywords)
            }
            return .aside(Element[.aside]
            {
                [keyword]
            }
            content:
            {
                Element[.h2]
                {
                    keyword
                }
                
                content
            })
            
        default:
            throw Documentation.CommentError.unsupportedMagicKeywords(keywords)
        }
    }
    
    private static
    func parameters(in content:[Element]) throws -> [(name:String, comment:[Element])]
    {
        guard let first:Element = content.first 
        else 
        {
            throw Documentation.CommentError.emptyParameterList
        }
        // look for a nested list 
        guard case .container(.ul, attributes: _, content: let items) = first 
        else 
        {
            throw Documentation.CommentError.invalidParameterList(first)
        }
        if let second:Element = content.dropFirst().first
        {
            throw Documentation.CommentError.multipleParameterLists(first, second)
        }
        
        var parameters:[(name:String, comment:[Element])] = []
        for item:Element in items
        {
            guard   case .container(.li, attributes: _, content: let content) = item, 
                    let (keywords, content):([String], [Element]) = Self.keywords(prefixing: content), 
                    let name:String = keywords.first, keywords.count == 1
            else 
            {
                throw Documentation.CommentError.invalidParameterListItem(item)
            }
            parameters.append((name, content))
        }
        return parameters
    }
    
    private static
    func keywords(prefixing content:[Element]) -> (keywords:[String], trimmed:[Element])?
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
        guard   case .container(.p, attributes: let attributes, content: var inline)? = content.first, 
                let first:Element = inline.first 
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
        case .container(let type, attributes: _, content: let styled):
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
            return (keywords, [Element].init(content.dropFirst()))
        }
        else 
        {
            var content:[Element] = content
                content[0] = .container(.p, attributes: attributes, content: inline)
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

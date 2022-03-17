import StructuredDocument 
import HTML

extension Biome 
{
    func article(package _:Int, comment:String) -> Documentation.Article
    {
        .init(comment: comment, biome: self)
    }
    func article(module _:Int, comment:String) -> Documentation.Article
    {
        .init(comment: comment, biome: self)
    }
    func article(symbol index:Int, comment:String) -> Documentation.Article
    {
        if case _? = self.symbols[index].commentOrigin 
        {
            // don’t re-render duplicated docs 
            return .init()
        }
        else 
        {
            return .init(comment: comment, biome: self)
        }
    }
}
extension Documentation 
{
    typealias StaticElement = HTML.Element<Never>
    
    enum Comment 
    {
        enum MagicListItem 
        {
            case parameters([(name:String, comment:[StaticElement])])
            case returns([StaticElement])
            case aside(StaticElement)
        }
        
        static 
        func magic(item:[StaticElement]) throws -> MagicListItem?
        {
            guard let (keywords, content):([String], [StaticElement]) = Self.keywords(prefixing: item)
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
                    throw LegacyAsideFieldError.unsupported(keywords: keywords)
                }
                return .parameters(try Self.parameters(in: content))
                
            case "parameter": 
                guard keywords.count == 2 
                else 
                {
                    throw LegacyAsideFieldError.unsupported(keywords: keywords)
                }
                let name:String = keywords[1]
                if content.isEmpty
                {
                    throw ParametersFieldError.empty(parameter: name)
                } 
                return .parameters([(name, content)])
            
            case "returns":
                guard keywords.count == 1 
                else 
                {
                    throw LegacyAsideFieldError.unsupported(keywords: keywords)
                }
                if content.isEmpty
                {
                    throw ReturnsFieldError.empty
                }
                return .returns(content)
            
            case "tip", "note", "info", "warning", "throws", "important", "precondition", "complexity":
                guard keywords.count == 1 
                else 
                {
                    throw LegacyAsideFieldError.unsupported(keywords: keywords)
                }
                return .aside(StaticElement[.aside]
                {
                    [keyword]
                }
                content:
                {
                    StaticElement[.h2]
                    {
                        keyword
                    }
                    
                    content
                })
                
            default:
                throw LegacyAsideFieldError.unsupported(keywords: keywords)
            }
        }
        
        private static
        func parameters(in content:[StaticElement]) throws -> [(name:String, comment:[StaticElement])]
        {
            guard let first:StaticElement = content.first 
            else 
            {
                throw ParametersFieldError.empty(parameter: nil)
            }
            // look for a nested list 
            guard case .container(.ul, id: _, attributes: _, content: let items) = first 
            else 
            {
                throw ParametersFieldError.invalidList(first)
            }
            if case _? = content.dropFirst().first
            {
                throw ParametersFieldError.multipleLists(content)
            }
            
            var parameters:[(name:String, comment:[StaticElement])] = []
            for item:StaticElement in items
            {
                guard   case .container(.li, id: _, attributes: _, content: let content) = item, 
                        let (keywords, content):([String], [StaticElement]) = Self.keywords(prefixing: content), 
                        let name:String = keywords.first, keywords.count == 1
                else 
                {
                    throw ParametersFieldError.invalidListItem(item)
                }
                parameters.append((name, content))
            }
            return parameters
        }
        
        private static
        func keywords(prefixing content:[StaticElement]) -> (keywords:[String], trimmed:[StaticElement])?
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
                    let first:StaticElement = inline.first 
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
                return (keywords, [StaticElement].init(content.dropFirst()))
            }
            else 
            {
                var content:[StaticElement] = content
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
    
    struct Article 
    {
        var errors:[ArticleError]
        
        private 
        let baked:
        (
            summary:String?, 
            discussion:String?
        )
        
        var summary:Element?
        {
            self.baked.summary.map(Element.text(escaped:))
        }
        var discussion:Element?
        {
            self.baked.discussion.map(Element.text(escaped:))
        }
        
        var size:Int 
        {
            var size:Int = self.baked.summary?.utf8.count     ?? 0
            size        += self.baked.discussion?.utf8.count  ?? 0
            return size
        }
        
        var substitutions:[Anchor: Element] 
        {
            var substitutions:[Anchor: Element] = [:]
            if let summary:Element = self.summary
            {
                substitutions[.summary]     = summary
            }
            if let discussion:Element = self.discussion
            {
                substitutions[.discussion]  = discussion
            }
            return substitutions
        }
                
        init() 
        {
            self.baked = (nil, nil)
            self.errors = []
        }
        
        init(summary:StaticElement?, discussion:[StaticElement], errors:[ArticleError])
        {
            self.baked.discussion   = discussion.isEmpty ? nil : discussion.map(\.rendered).joined()
            self.baked.summary      = summary?.rendered
            self.errors             = errors 
        }
        init(comment:String, biome:Biome)
        {
            let (summary, toplevel):(StaticElement?, [StaticElement]) 
            var errors:[ArticleError]
            do 
            {
                var renderer:MarkdownDiagnostic.Renderer = .init()
                (summary, toplevel) = renderer.render(comment: comment, biome: biome)
                errors = renderer.errors.map(ArticleError.markdown(_:))
            }
            
            var parameters:[(name:String, comment:[StaticElement])] = []
            var returns:[StaticElement]      = []
            var discussion:[StaticElement]   = []
            for block:StaticElement in toplevel 
            {
                // filter out top-level ‘ul’ blocks, since they may be special 
                guard case .container(.ul, id: let id, attributes: let attributes, content: let items) = block 
                else 
                {
                    discussion.append(block)
                    continue 
                }
                
                var ignored:[StaticElement] = []
                listitems:
                for item:StaticElement in items
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
                                throw Comment.ReturnsFieldError.duplicate(section: section)
                            }
                        case .aside(let section):
                            discussion.append(section)
                        }
                        
                        continue listitems
                    }
                    catch let error as Comment.LegacyAsideFieldError
                    {
                        errors.append(.legacyAside(error))
                    }
                    catch let error as Comment.ParametersFieldError
                    {
                        errors.append(.parameters(error))
                    }
                    catch let error as Comment.ReturnsFieldError
                    {
                        errors.append(.returns(error))
                    }
                    catch let error 
                    {
                        fatalError("unreachable: \(error)")
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
            
            var sections:[StaticElement] = []
            if !parameters.isEmpty
            {
                sections.append(Self.render(parameters: parameters))
            }
            if !returns.isEmpty
            {
                sections.append(Self.render(section: returns, heading: "Returns",  class: "returns"))
            }
            if !discussion.isEmpty
            {
                sections.append(Self.render(section: discussion, heading: "Overview", class: "discussion"))
            }
            
            self.init(summary: summary, discussion: sections, errors: errors)
        }
        
        private static 
        func render(section content:[StaticElement], heading:String, class:String) -> StaticElement
        {
            StaticElement[.section]
            {
                [`class`]
            }
            content: 
            {
                StaticElement[.h2]
                {
                    heading
                }
                content
            }
        }
        private static 
        func render(parameters:[(name:String, comment:[StaticElement])]) -> StaticElement
        {
            StaticElement[.section]
            {
                ["parameters"]
            }
            content: 
            {
                StaticElement[.h2]
                {
                    "Parameters"
                }
                StaticElement[.dl]
                {
                    for (name, comment):(String, [StaticElement]) in parameters 
                    {
                        StaticElement[.dt]
                        {
                            name
                        }
                        StaticElement[.dd]
                        {
                            comment
                        }
                    }
                }
            }
        }
    }
}

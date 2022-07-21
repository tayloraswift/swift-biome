import Markdown

extension Extension 
{
    struct Sections 
    {
        typealias Parameter = (name:String, content:[any BlockMarkup])
        typealias Topic = (heading:Heading, items:[String])

        var parameters:[Parameter] 
        var returns:[any BlockMarkup] 
        var topics:[Topic]
        
        init()
        {
            self.parameters = []
            self.returns = []
            self.topics = []
        }
        
        mutating 
        func recognize(nodes:[Node]) -> [Node]
        {
            var replaced:[Node] = []
            for node:Node in nodes 
            {
                switch node 
                {
                case .section(let heading, let children):
                    #if false
                    if  heading.level == 2, heading.plainText == "Topics"
                    {
                        if let topics:[Topic] = Self.recognize(topics: children)
                        {
                            self.topics.append(contentsOf: topics)
                            continue 
                        }
                        print("warning: malformed topics section")
                    }
                    #endif
                    replaced.append(.section(heading, self.recognize(nodes: children)))

                case .block(let list as UnorderedList):
                    replaced.append(contentsOf: self.recognize(unordered: list))
                default:
                    replaced.append(node)
                }
            }
            return replaced
        }
        private mutating 
        func recognize(unordered:UnorderedList) -> [Node] 
        {
            var muggles:[Node] = []
            for item:ListItem in unordered.listItems 
            {
                guard case let (keyword, content)? = 
                    item.recognize(where: Keyword.init(_:))
                else 
                {
                    muggles.append(.block(item))
                    continue 
                }
                magic:
                switch keyword 
                {
                case .other(let unknown):
                    print("warning: unknown keyword '\(unknown)'")
                
                case .aside(let aside): 
                    muggles.append(.aside(aside, .init(content)))
                    continue 
                
                case .returns:
                    returns.append(contentsOf: content)
                    continue 
                
                case .parameter(let parameter):
                    parameters.append((parameter, content))
                    continue 
                
                case .parameters:
                    var group:[Parameter] = []
                    for block:any BlockMarkup in content
                    {
                        guard let unordered:UnorderedList = block as? UnorderedList 
                        else 
                        {
                            // expected unordered list
                            break magic
                        }
                        for inner:ListItem in unordered.listItems
                        {
                            let recognized:(String, [any BlockMarkup])? = inner.recognize
                            {
                                $0.contains(where: \.isWhitespace) ? nil : String.init($0)
                            }
                            guard case let (parameter, content)? = recognized
                            else 
                            {
                                break magic
                            }
                            group.append((parameter, content))
                        }
                    }
                    parameters.append(contentsOf: group)
                    continue 
                }
                
                muggles.append(.block(item))
            }
            
            var fractured:[Node] = []
            var sublist:[ListItem] = []
            for muggle:Node in muggles 
            {
                if case .block(let item as ListItem) = muggle
                {
                    sublist.append(item)
                    continue 
                }
                else if !sublist.isEmpty
                {
                    fractured.append(.block(UnorderedList.init(sublist)))
                    sublist = []
                }
                fractured.append(muggle)
            }
            if !sublist.isEmpty
            {
                fractured.append(.block(UnorderedList.init(sublist)))
            }
            return fractured
        }
        private static 
        func recognize(topics nodes:[Node]) -> [Topic]? 
        {
            var topics:[Topic] = [] 
                topics.reserveCapacity(nodes.count)
            for node:Node in nodes 
            {
                guard case .section(let heading, let blocks) = node, 
                    heading.level == 3
                else 
                {
                    return nil
                }

                var description:[any BlockMarkup] = []
                var topic:[String] = []
                for block:Node in blocks 
                {
                    guard case .block(let block) = block
                    else 
                    {
                        return nil
                    }
                    guard let list:UnorderedList = block as? UnorderedList 
                    else 
                    {
                        // if there are non-list children, they must appear 
                        // before the first list.
                        // sometimes there are HTML comments, which we ignore
                        if topic.isEmpty || block is HTMLBlock
                        {
                            description.append(block)
                            continue 
                        }
                        return nil
                    }
                    for item:ListItem in list.listItems 
                    {
                        for paragraph:any BlockMarkup in item.blockChildren 
                        {
                            guard let paragraph:any InlineContainer = 
                                paragraph as? InlineContainer 
                            else 
                            {
                                return nil
                            }
                            for span:any InlineMarkup in paragraph.inlineChildren 
                            {
                                let destination:String?
                                switch span 
                                {
                                case let link as Markdown.Link:
                                    destination = link.destination
                                case let link as Markdown.SymbolLink:
                                    destination = link.destination
                                default: 
                                    return nil
                                }
                                guard let destination:String, !destination.isEmpty
                                else 
                                {
                                    return nil
                                }
                                topic.append(destination)
                            }
                        }
                    }
                }
                topics.append((heading, topic))
            }
            return topics
        }
    }
}

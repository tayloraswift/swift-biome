import Markdown

extension Extension 
{
    struct Sections 
    {
        var parameters:[(String, [any BlockMarkup])] = []
        var returns:[any BlockMarkup] = []
        
        init()
        {
            self.parameters = []
            self.returns = []
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
                    var group:[(String, [any BlockMarkup])] = []
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
    }
}

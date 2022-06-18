/* import StructuredDocument
import HTML 

extension Documentation 
{
    func dynamicContent(package index:Int) -> [Element]
    {
        [
            Element[.section]
            {
                ["relationships"]
            }
            content: 
            {
                Element[.h2]
                {
                    "Modules"
                }
                Element[.ul]
                {
                    for module:Int in self.biome.packages[index].modules
                    {
                        Element[.li]
                        {
                            Element[.code]
                            {
                                ["signature"]
                            }
                            content: 
                            {
                                self.item(module: module)
                            }
                        }
                    }
                }
            },
        ]
    }
    func dynamicContent(module index:Int) -> (sections:[Element], cards:Set<Int>)
    {
        let module:Module = self.biome.modules[index]
        let groups:[Bool: [Int]] = self.biome.partition(symbols: module.toplevel)
        var sections:[Element] = []
        self.topics(self.biome.organize(symbols: groups[false, default: []], in: nil), heading: "Members").map 
        {
            sections.append($0)
        }
        self.topics(self.biome.organize(symbols: groups[true,  default: []], in: nil), heading: "Removed Members").map 
        {
            sections.append($0)
        }
        return (sections, Set<Int>.init(self.biome.comments(backing: module.toplevel)))
    }
    func dynamicContent(witness:Int) -> (sections:[Element], cards:Set<Int>)
    {
        let symbol:Symbol     = self.biome.symbols[witness]
        
        let groups:[Bool: [Int]] = symbol.relationships.members.map(self.biome.partition(symbols:)) ?? [:]
        var cards:Set<Int> = symbol.relationships.members.map(self.biome.comments(backing:)).map(Set.init(_:)) ?? []
        
        var sections:[Element] = []
        if case .protocol(let abstract) = symbol.relationships 
        {
            cards.formUnion(self.biome.comments(backing: abstract.requirements))
            
            self.list(types: abstract.downstream.map { ($0, []) }, heading: "Refinements").map 
            {
                sections.append($0)
            }
            self.topics(self.biome.organize(symbols: abstract.requirements, in: witness), heading: "Requirements").map 
            {
                sections.append($0)
            }
        }
        
        self.topics(self.biome.organize(symbols: groups[false, default: []], in: witness), heading: "Members").map 
        {
            sections.append($0)
        }
        
        switch symbol.relationships 
        {
        case .protocol(let abstract):
            self.list(types: abstract.upstream.map{ ($0, []) },    heading: "Implies").map 
            {
                sections.append($0)
            }
            self.list(types: abstract.conformers,                  heading: "Conforming Types").map 
            {
                sections.append($0)
            }
        case .class(let concrete, subclasses: let subclasses, superclass: _):
            self.list(types: subclasses.map { ($0, []) },          heading: "Subclasses").map 
            {
                sections.append($0)
            }
            self.list(types: concrete.upstream,                    heading: "Conforms To").map 
            {
                sections.append($0)
            }
        case .enum(let concrete), .struct(let concrete), .actor(let concrete):
            self.list(types: concrete.upstream,                    heading: "Conforms To").map 
            {
                sections.append($0)
            }
        default: 
            break
        }
        self.topics(self.biome.organize(symbols: groups[true, default: []], in: witness), heading: "Removed Members").map 
        {
            sections.append($0)
        }
        return (sections, cards)
    }
    
    private 
    func item(module:Int) -> Element
    {
        return Element[.a]
        {
            (self.format(uri: self.uri(module: module)), as: HTML.Href.self)
        }
        content: 
        {
            Element.highlight(self.biome.modules[module].id.string, .identifier)
        }
    }
} */

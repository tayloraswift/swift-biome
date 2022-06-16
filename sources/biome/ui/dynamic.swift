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
    private 
    func item(symbol:Int) -> Element
    {
        self.item(symbol: symbol, displaying: symbol)
    }
    private 
    func item(symbol:Int, displaying display:Int) -> Element
    {
        return Element[.a]
        {
            (self.format(uri: self.uri(witness: symbol, victim: nil)), as: HTML.Href.self)
        }
        content: 
        {
            for component:String in self.biome.symbols[display].scope 
            {
                Element.highlight(component, .identifier)
                Element.highlight(".", .text)
            }
            Element.highlight(self.biome.symbols[display].title, .identifier)
        }
    }
    
    private 
    func card(witness:Int, victim:Int?) -> Element
    {
        let symbol:Symbol = self.biome.symbols[witness]
        let availability:[Element]  = Self.availability(symbol.availability)
        var relationships:[Element] = []
        if  case nil = victim, 
            let overridden:Int  =                   symbol.relationships.overrideOf, 
            let interface:Int   = self.biome.symbols[overridden].parent 
        {
            relationships.append(Element[.li]
            {
                Element[.p]
                {
                    if case .protocol = self.biome.symbols[interface].kind
                    {
                        "Refines requirement in "
                    } 
                    else 
                    {
                        "Overrides virtual member in "
                    } 
                    Element[.code]
                    {
                        self.item(symbol: overridden, displaying: interface)
                    }
                }
            })
        } 
        return Element[.li]
        {
            Element[.code]
            {
                ["signature"]
            }
            content: 
            {
                Element[.a]
                {
                    (self.format(uri: self.uri(witness: witness, victim: victim)), as: HTML.Href.self)
                }
                content: 
                {
                    symbol.signature.content.map(Element.highlight(_:_:))
                }
            }
            
            Element.anchor(id: .reference(.symbol(symbol.sponsor ?? witness, victim: nil)))
            
            if !relationships.isEmpty 
            {
                Element[.ul]
                {
                    ["relationships-list"]
                }
                content: 
                {
                    relationships
                }
            }
            if !availability.isEmpty 
            {
                Element[.ul]
                {
                    ["availability-list"]
                }
                content: 
                {
                    availability
                }
            }
        }
    }
    
    private 
    func topics<S>(_ topics:S, heading:String) -> Element?
        where S:Sequence, S.Element == (heading:Topic, symbols:[(witness:Int, victim:Int?)])
    {
        let topics:[Element] = topics.map
        {
            (topic:(heading:Topic, symbols:[(witness:Int, victim:Int?)])) in 

            return Element[.div]
            {
                ["topic-container"]
            }
            content:
            {
                Element[.div]
                {
                    ["topic-container-left"]
                }
                content:
                {
                    Element[.h3]
                    {
                        topic.heading.description
                    }
                }
                Element[.ul]
                {
                    ["topic-container-right"]
                }
                content:
                {
                    for (witness, victim):(Int, Int?) in topic.symbols
                    {
                        self.card(witness: witness, victim: victim)
                    }
                }
            }
        }
        guard !topics.isEmpty 
        else 
        {
            return nil
        }
        return Element[.section]
        {
            ["topics"]
        }
        content: 
        {
            Element[.h2]
            {
                heading
            }
            topics
        }
    }
} */

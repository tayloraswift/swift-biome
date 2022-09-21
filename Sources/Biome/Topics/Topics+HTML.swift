import HTML 

extension _Topics 
{
    // func html(context:Package.Context, cache:inout _ReferenceCache) -> HTML.Element<Never>?
    // {
    //     var sections:[HTML.Element<Never>] = []
        
    //     topics.feed.isEmpty ? [] : 
    //     [
    //         .section(self.render(cards: topics.feed), attributes: [.class("feed")])
    //     ]
        
    //     func add(lists:Page.List...)
    //     {
    //         for list:Page.List in lists
    //         {
    //             if  let segregated:[Module._Culture: [Generic.Conditional<Symbol.Index>]] = 
    //                 topics.lists[list]
    //             {
    //                 sections.append(self.render(section: segregated, heading: list.rawValue))
    //             }
    //         }
    //     }
        
    //     add(lists: .refinements, .implementations, .restatements, .overrides)
        
    //     if !topics.requirements.isEmpty
    //     {
    //         let requirements:[Page.Sublist: [Module._Culture: [Page.Card]]] = 
    //             topics.requirements.mapValues { [.primary: $0] }
    //         sections.append(self.render(section: requirements, 
    //             heading: "Requirements", 
    //             class: "requirements"))
    //     }
    //     if !topics.members.isEmpty
    //     {
    //         sections.append(self.render(section: topics.members, 
    //             heading: "Members", 
    //             class: "members"))
    //     }
        
    //     add(lists: .conformers, .conformances, .subclasses, .implications)
        
    //     if !topics.removed.isEmpty
    //     {
    //         sections.append(self.render(section: topics.removed, 
    //             heading: "Removed Members", 
    //             class: "removed"))
    //     }
        
    //     return sections.isEmpty ? nil : 
    //         .init(freezing: .div(sections))
    // }
}

extension Sequence<_Topics.SymbolCard>
{
    func html(context:Package.Context, cache:inout _ReferenceCache) 
        throws -> HTML.Element<Never>? 
    {
        let items:[HTML.Element<Never>] = try self.map 
        {
            let signature:HTML.Element<Never> = .a(.render(signature: $0.signature), 
                attributes:
                [
                    .href(try cache.uri(of: $0.composite, context: context)),
                    .class("signature")
                ])
            if  $0.overview.isEmpty 
            {
                return .li(signature)
            }
            else 
            {
                return .li(signature, try cache.link($0.overview, context: context))
            }
        }
        return items.isEmpty ? nil : .ul(items)
    }
}
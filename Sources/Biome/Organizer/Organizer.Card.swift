import DOM 
import HTML
import Notebook

extension Organizer 
{
    enum SortingKey:Comparable 
    {
        case atomic   (Path)
        case compound((Path, String))

        static 
        func == (lhs:Self, rhs:Self) -> Bool 
        {
            switch (lhs, rhs)
            {
            case    (.atomic(let a), .atomic(let b)): 
                return a == b 
            
            case    (.atomic(let a), .compound(let b)), 
                    (.compound(let b), .atomic(let a)): 
                return a.last == b.1 && a.prefix.elementsEqual(b.0)
            
            case    (.compound(let a), .compound(let b)): 
                return a == b
            }
        }
        static 
        func < (lhs:Self, rhs:Self) -> Bool 
        {
            switch (lhs, rhs)
            {
            case    (.atomic(let lhs), .atomic(let rhs)): 
                return lhs |<| rhs 
            
            case    (.atomic(let lhs), .compound(let rhs)): 
                return (lhs.prefix, lhs.last) |<| rhs
            
            case    (.compound(let lhs), .atomic(let rhs)): 
                return lhs |<| (rhs.prefix, rhs.last)
            
            case    (.compound(let lhs), .compound(let rhs)): 
                return lhs |<| rhs
            }
        }
    }
    struct Card<Signature>
    {
        typealias Unsorted = (card:Card<Signature>, key:SortingKey)

        let signature:Signature
        let overview:DOM.Flattened<GlobalLink.Presentation>
        let uri:String 

        init(signature:Signature, 
            overview:DOM.Flattened<GlobalLink.Presentation>, 
            uri:String)
        {
            self.signature = signature
            self.overview = overview
            self.uri = uri
        }
    }
}
extension Sequence 
{
    func sorted<T>() -> [Organizer.Card<T>] 
        where Element == Organizer.Card<T>.Unsorted
    {
        self.sorted { $0.key < $1.key } .map(\.card)
    }
}

extension Organizer.Card<Notebook<Highlight, Never>>
{
    func html(context:some PackageContext, cache:inout ReferenceCache) 
        throws -> HTML.Element<Never>
    {
        let signature:HTML.Element<Never> = .a(.render(signature: self.signature), 
            attributes: [.href(self.uri), .class("signature")])
        if  let utf8:[UInt8] = try cache.link(self.overview, context: context)
        {
            return .li(signature, .init(node: .value(.init(escaped: _move utf8))))
        }
        else 
        {
            return .li(signature)
        }
    }
}
// extension Sequence<_Topics.Card<Notebook<Highlight, Never>>>
// {
//     func html(context:IsotropicContext, cache:inout ReferenceCache) 
//         throws -> HTML.Element<Never>? 
//     {
//         let items:[HTML.Element<Never>] = try self.map 
//         {
//             try $0.html(context: context, cache: &cache)
//         }
//         return items.isEmpty ? nil : .ul(items)
//     }
// }
import HTML 
import Notebook

extension Organizer 
{
    struct Enclave<Element>
    {
        let culture:Culture 
        var elements:[Element]

        init(_ culture:Culture, elements:[Element] = [])
        {
            self.culture = culture 
            self.elements = elements
        }
    }
}
extension Organizer.Enclave 
{
    func sorted<T>() -> Organizer.Enclave<Organizer.Card<T>> 
        where Element == Organizer.Card<T>.Unsorted 
    {
        .init(self.culture, elements: self.elements.sorted())
    }
    func sorted<T>() -> Self 
        where Element == Organizer.Item<T> 
    {
        .init(self.culture, elements: self.elements.sorted())
    }
}
extension Sequence 
{
    func sorted<T>() -> [Element] 
        where Element == Organizer.Enclave<T> 
    {
        self.sorted { $0.culture.sortingKey < $1.culture.sortingKey } 
    }
}

extension Organizer.Enclave
{
    private 
    func h3(elements:[HTML.Element<Never>]) -> [HTML.Element<Never>] 
    {
        if let heading:[HTML.Element<Never>] = self.culture.html 
        {
            return [.h3(heading), .ul(elements)]
        }
        else 
        {
            return [.ul(elements)]
        }
    }
    private 
    func h4(elements:[HTML.Element<Never>]) -> [HTML.Element<Never>] 
    {
        if let heading:[HTML.Element<Never>] = self.culture.html 
        {
            return [.h4(heading), .ul(elements)]
        }
        else 
        {
            return [.ul(elements)]
        }
    }
}
extension Organizer.Enclave<Organizer.Card<Notebook<Highlight, Never>>>
{
    func html(context:Package.Context, cache:inout _ReferenceCache) 
        throws -> [HTML.Element<Never>] 
    {
        self.h4(elements: try self.elements.map 
        {
            try $0.html(context: context, cache: &cache)
        })
    }
}
extension Organizer.Enclave:HTMLConvertible where Element:HTMLConvertible
{
    var html:[HTML.Element<Never>] 
    {
        self.h3(elements: self.elements.flatMap(\.html))
    }
}
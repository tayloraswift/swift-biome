import HTML 
import Notebook

extension _Topics 
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
extension _Topics.Enclave 
{
    func sorted<T>() -> _Topics.Enclave<_Topics.Card<T>> 
        where Element == _Topics.Card<T>.Unsorted 
    {
        .init(self.culture, elements: self.elements.sorted())
    }
    func sorted<T>() -> Self 
        where Element == _Topics.Item<T> 
    {
        .init(self.culture, elements: self.elements.sorted())
    }
}
extension Sequence 
{
    func sorted<T>() -> [Element] 
        where Element == _Topics.Enclave<T> 
    {
        self.sorted { $0.culture.sortingKey < $1.culture.sortingKey } 
    }
}

extension _Topics.Enclave
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
extension _Topics.Enclave<_Topics.Card<Notebook<Highlight, Never>>>
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
extension _Topics.Enclave<_Topics.Item<[Generic.Constraint<String>]>>
{
    var html:[HTML.Element<Never>] 
    {
        self.h3(elements: self.elements.map(\.html))
    }
}
extension _Topics.Enclave<_Topics.Item<Void>>
{
    var html:[HTML.Element<Never>] 
    {
        self.h3(elements: self.elements.map(\.html))
    }
}
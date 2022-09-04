extension Branch 
{
    struct Divergences<Element>:ExpressibleByDictionaryLiteral where Element:BranchElement 
    {
        private 
        var items:[Position<Element>: Element.Divergence]

        subscript(key:Position<Element>) -> Element.Divergence?
        {
            _read 
            {
                yield  self.items[key]
            }
            _modify 
            {
                yield &self.items[key]
            }
        }

        init(dictionaryLiteral:(Position<Element>, Element.Divergence)...)
        {
            self.items = .init(uniqueKeysWithValues: dictionaryLiteral)
        }
        /// Returns the forest head to the divergent history of the given field, 
        /// if it both exists and began before the specified revision.
        /// 
        /// This head may have been advanced beyond the bounds of the 
        /// ``Buffer/SubSequence`` it was obtained from, if applicable. However 
        /// if this method returns a non-nil result, the specified revision 
        /// is guaranteed to exist in the associated chain.
        func head<Versioned>(_ key:Position<Element>, 
            _ field:KeyPath<Element.Divergence, Divergence<Versioned>?>, 
            containing revision:_Version.Revision)
            -> Head<Versioned>?
        {
            if  let divergence:Divergence<Versioned> = self.items[key]?[keyPath: field], 
                    divergence.start <= revision
            {
                return divergence.head
            }
            else 
            {
                return nil
            }
        }
    }
}
extension Branch.Divergences where Element.Divergence:Voidable
{
    subscript(filling key:Branch.Position<Element>) -> Element.Divergence
    {
        _read 
        {
            yield  self.items[key, default: .init()]
        }
        _modify 
        {
            yield &self.items[key, default: .init()]
        }
    }
}
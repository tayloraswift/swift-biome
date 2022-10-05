import SymbolGraphs
import SymbolSource

extension ModuleInterface
{
    struct Abstractor<Element>:RandomAccessCollection where Element:AtomicElement 
    {
        private 
        var table:[Atom<Element>.Position?]
        private 
        let updated:Int

        var startIndex:Int
        {
            self.table.startIndex
        }
        var endIndex:Int
        {
            self.table.endIndex
        }
        subscript(index:Int) -> Atom<Element>.Position? 
        {
            _read 
            {
                yield  self.table[index]
            }
            _modify
            {
                yield &self.table[index]
            }
        }

        init(_ table:__owned [Atom<Element>.Position?])
        {
            self.table = table 
            self.updated = self.table.endIndex
        }

        func citizens(culture:Element.Culture) -> Citizens<Element> 
        {
            .init(self.table.prefix(upTo: self.updated), culture: culture)
        }

        mutating 
        func extend(over identifiers:[Element.ID], 
            by find:(Element.ID) throws -> Atom<Element>.Position?) rethrows 
        {
            for external:Element.ID in identifiers.suffix(from: self.table.endIndex)
            {
                self.table.append(try find(external))
            }
        }
    }
}

import SymbolGraphs
import SymbolSource

extension ModuleInterface
{
    struct SymbolLookupError:Error 
    {
        let index:Int 

        init(_ index:Int)
        {
            self.index = index
        }
    }
    struct SymbolPositions
    {
        private
        let positions:[Atom<Symbol>.Position?]
        private
        let citizens:Range<Int>

        init(_ positions:[Atom<Symbol>.Position?], citizens:Range<Int>)
        {
            self.positions = positions
            self.citizens = citizens
        }
    }
}
extension ModuleInterface.SymbolPositions
{
    subscript(index:Int) -> Atom<Symbol>.Position? 
    {
        self.positions[index]
    }

    func citizens(culture:Atom<Module>) -> ModuleInterface.SymbolCitizens
    {
        .init(positions: self.positions[self.citizens], culture: culture)
    }
}
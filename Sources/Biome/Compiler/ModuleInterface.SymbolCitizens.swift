extension ModuleInterface
{
    struct SymbolCitizens
    {
        private 
        let positions:ArraySlice<Atom<Symbol>.Position?>
        let culture:Atom<Module>

        init(positions:ArraySlice<Atom<Symbol>.Position?>, culture:Atom<Module>)
        {
            self.positions = positions 
            self.culture = culture 
        }
    }
}
extension ModuleInterface.SymbolCitizens:RandomAccessCollection
{
    var startIndex:Int
    {
        self.positions.startIndex
    }
    var endIndex:Int
    {
        self.positions.endIndex
    }
    // the `prefix` excludes symbols that were once in the current package, 
    // but for whatever reason were left out of the current version of the 
    // current package.
    // the `flatMap` excludes symbols that are not native to the current 
    // module. this happens sometimes due to member inference.
    subscript(index:Int) -> Atom<Symbol>.Position? 
    {
        self.positions[index].flatMap { self.culture == $0.culture ? $0 : nil }
    }
}
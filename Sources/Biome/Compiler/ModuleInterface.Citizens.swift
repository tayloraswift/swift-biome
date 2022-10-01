extension ModuleInterface
{
    struct Citizens<Element>:RandomAccessCollection where Element:BranchElement
    {
        private 
        let table:ArraySlice<Atom<Element>.Position?>
        let culture:Element.Culture

        init(_ table:ArraySlice<Atom<Element>.Position?>, culture:Element.Culture)
        {
            self.table = table 
            self.culture = culture 
        }

        var startIndex:Int
        {
            self.table.startIndex
        }
        var endIndex:Int
        {
            self.table.endIndex
        }
        // the `prefix` excludes symbols that were once in the current package, 
        // but for whatever reason were left out of the current version of the 
        // current package.
        // the `flatMap` excludes symbols that are not native to the current 
        // module. this happens sometimes due to member inference.
        subscript(index:Int) -> Atom<Element>.Position? 
        {
            self.table[index].flatMap { self.culture == $0.culture ? $0 : nil }
        }
    }
}
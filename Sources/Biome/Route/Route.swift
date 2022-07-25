struct Route 
{
    let key:Key 
    let target:Symbol.Composite 

    init(key:Key, target:Symbol.Composite)
    {
        self.key = key 
        self.target = target 
    }

    typealias Trees = (natural:[NaturalTree], synthetic:[SyntheticTree])

    struct NaturalTree 
    {
        let key:Key
        let target:Symbol.Index

        var route:Route 
        {
            .init(key: key, target: .init(natural: self.target))
        }
    }
    struct SyntheticTree:RandomAccessCollection
    {
        let namespace:Module.Index 
        let stem:Stem 
        
        let diacritic:Symbol.Diacritic 
        let features:[(base:Symbol.Index, leaf:Leaf)]

        var startIndex:Int 
        {
            self.features.startIndex
        }
        var endIndex:Int 
        {
            self.features.endIndex
        }
        subscript(index:Int) -> Route
        {
            let (base, leaf):(Symbol.Index, Leaf) = self.features[index]
            return .init(key: .init(self.namespace, self.stem, leaf), 
                target: .init(base, self.diacritic))
        }
    }
}

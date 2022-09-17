import URI 
import Versions


extension URI 
{
    mutating 
    func insert(parameters query:Symbol.Link.Query)
    {
        if let base:Symbol.ID = query.base
        {
            self.insert(parameter: (Symbol.Link.Query.base, base.string))
        }
        if let host:Symbol.ID = query.host
        {
            self.insert(parameter: (Symbol.Link.Query.host, host.string))
        }
        guard let lens:Symbol.Link.Lens = query.lens 
        else 
        {
            return 
        }
        if let version:MaskedVersion = lens.version 
        {
            self.insert(parameter: (Symbol.Link.Query.lens, 
                "\(lens.culture.string)/\(version.description)"))
        }
        else 
        {
            self.insert(parameter: (Symbol.Link.Query.lens, lens.culture.string))
        }
    }
}
extension RangeReplaceableCollection where Element == URI.Vector? 
{
    @available(*, deprecated)
    mutating 
    func append<Components>(components:Components, orientation:_SymbolLink.Orientation)
        where Components:BidirectionalCollection, Components.Element == String
    {
        guard case .gay = orientation, components.startIndex < components.endIndex
        else 
        {
            self.append(components: components)
            return 
        }
        
        let ultimate:Components.Index = components.index(before: components.endIndex)
        
        guard components.startIndex < ultimate 
        else 
        {
            self.append(components: components)
            return 
        }
        
        let penultimate:Components.Index = components.index(before: ultimate)
        
        self.reserveCapacity(self.underestimatedCount + 
            components[..<ultimate].underestimatedCount)
        for component:String in components[..<penultimate]
        {
            self.append(component: component)
        }
        self.append(component: "\(components[penultimate]).\(components[ultimate])")
    }
}
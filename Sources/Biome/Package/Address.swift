import URI

struct Address 
{
    struct Global
    {
        var residency:Package.ID?
        var version:Version.Selector?
        var local:Local?

        init(residency:Package.ID?, version:Version.Selector?, local:Local? = nil)
        {
            self.residency = residency
            self.version = version
            self.local = local
        }
    }
    struct Local
    {
        var namespace:Module.ID 
        var symbolic:Symbolic?

        init(namespace:Module.ID, symbolic:Symbolic? = nil)
        {
            self.namespace = namespace 
            self.symbolic = symbolic
        }
    }
    struct Symbolic 
    {
        var orientation:_SymbolLink.Orientation 
        var path:Path 
        var host:Symbol.ID? 
        var base:Symbol.ID?
        var nationality:_SymbolLink.Nationality?

        init(path:Path, orientation:_SymbolLink.Orientation)
        {
            self.orientation = orientation 
            self.path = path 
            self.host = nil 
            self.base = nil 
            self.nationality = nil 
        }
    }

    var function:Service.Function 
    var global:Global
}
extension Address 
{
    func uri(functions:Service.Functions) -> URI 
    {
        var uri:URI = functions.uri(self.function)

        if let residency:Package.ID = self.global.residency 
        {
            uri.path.append(component: residency.string)
        }
        if let version:Version.Selector = self.global.version 
        {
            uri.path.append(component: version.description)
        }
        if let local:Local = self.global.local 
        {
            if let symbolic:Symbolic = local.symbolic 
            {
                uri.path.append(first: local.namespace.value, 
                    lowercasing: symbolic.path, 
                    orientation: symbolic.orientation)
                
                if let base:Symbol.ID = symbolic.base
                {
                    uri.insert(parameter: (GlobalLink.Parameter.base.rawValue, base.string))
                }
                if let host:Symbol.ID = symbolic.host
                {
                    uri.insert(parameter: (GlobalLink.Parameter.host.rawValue, host.string))
                }
                if let nationality:_SymbolLink.Nationality = symbolic.nationality
                {
                    let value:String 
                    if let version:Version.Selector = nationality.version 
                    {
                        value = "\(nationality.id.string)/\(version.description)"
                    }
                    else 
                    {
                        value = nationality.id.string
                    }
                    uri.insert(parameter: (GlobalLink.Parameter.nationality.rawValue, value))
                }
            }
            else 
            {
                uri.path.append(component: local.namespace.value)
            }
        }
        
        return uri 
    }
}

extension RangeReplaceableCollection where Element == URI.Vector? 
{
    fileprivate mutating 
    func append(first:String, lowercasing path:Path, orientation:_SymbolLink.Orientation)
    {
        guard case .gay = orientation
        else 
        {
            self.append(component: first)
            self.append(components: path.lazy.map { $0.lowercased() })
            return 
        }
        
        let penultimate:String 
        if let last:String = path.prefix.last 
        {
            self.append(component: first)
            self.append(components: path.prefix.dropLast().lazy.map { $0.lowercased() })

            penultimate = last.lowercased() 
        }
        else 
        {
            penultimate = first 
        }
        
        self.append(component: "\(penultimate).\(path.last.lowercased())")
    }
}
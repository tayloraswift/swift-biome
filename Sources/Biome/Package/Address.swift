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
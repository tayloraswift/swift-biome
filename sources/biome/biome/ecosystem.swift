/// an ecosystem is a subset of a biome containing packages that are relevant 
/// (in some user-defined way) to some task. 
/// 
/// ecosystem views are mainly useful for providing an immutable context for 
/// accessing foreign packages.
struct Ecosystem 
{
    var packages:[Package], 
        indices:[Package.ID: Package.Index]
    
    init()
    {
        self.packages = []
        self.indices = [:]
    }
    
    subscript(package:Package.ID) -> Package?
    {
        self.indices[package].map { self[$0] }
    } 
    subscript(package:Package.Index) -> Package
    {
        _read 
        {
            yield self.packages[package.offset]
        }
        _modify 
        {
            yield &self.packages[package.offset]
        }
    } 
    subscript(module:Module.Index) -> Module
    {
        _read 
        {
            yield self.packages[module.package.offset].module.buffer[module.offset]
        }
        /* _modify 
        {
            yield &self.packages[module.package.offset].module.buffer[module.offset]
        } */
    } 
    subscript(symbol:Symbol.Index) -> Symbol
    {
        _read 
        {
            yield self.packages[symbol.module.package.offset].symbol.buffer[symbol.offset]
        }
        /* _modify 
        {
            yield &self.packages[symbol.module.package.offset].symbol.buffer[symbols.offset]
        } */
    } 
    /// returns the index of the entry for the given package, creating it if it 
    /// does not already exist.
    mutating 
    func create(package:Package.ID) -> Package.Index 
    {
        if let index:Package.Index = self.indices[package]
        {
            return index 
        }
        let index:Package.Index = .init(offset: self.packages.endIndex)
        self.packages.append(.init(id: package, index: index))
        return index
    }
}
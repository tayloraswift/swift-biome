protocol Cache 
{
    init()
    
    mutating 
    func regenerate(for package:Package.Index, from ecosystem:Ecosystem)
}
extension Cache 
{
    mutating 
    func regenerate(from ecosystem:Ecosystem)
    {
        self = .init()
        for package:Package.Index in ecosystem.indices.values 
        {
            self.regenerate(for: package, from: ecosystem)
        }
    }
}

import BiomeABI
import MongoKitten

public
struct Database:Sendable
{
    public
    func loadSurface(for nationality:Package, version:Version) async throws -> Surface 
    {
        fatalError("unimplemented")
    }

    public
    func storeSurface(_ surface:Surface, 
        for nationality:Package, 
        version:Version) async throws
    {
        fatalError("unimplemented")
    }

    // func storeDocumentation(_ literature:PackageDocumentation) async throws
    // {
    //     fatalError("unimplemented")
    // }
}

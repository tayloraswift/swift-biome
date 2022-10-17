//import MongoKitten

public
struct Database:Sendable
{
    func loadSurface(for nationality:Package, version:Version) async throws -> Surface 
    {
        fatalError("unimplemented")
    }

    func storeSurface(_ surface:Surface, 
        for nationality:Package, 
        version:Version) async throws
    {
        fatalError("unimplemented")
    }

    func storeDocumentation(_ literature:PackageDocumentation) async throws
    {
        fatalError("unimplemented")
    }
}

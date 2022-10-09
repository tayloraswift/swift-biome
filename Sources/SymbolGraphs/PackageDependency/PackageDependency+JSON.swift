import SymbolSource
import JSON

extension PackageDependency 
{
    private
    enum CodingKeys 
    {
        static let package:String = "package"
        static let modules:String = "modules"
    }
    public
    var serialized:JSON 
    {
        [
            CodingKeys.package: .string(self.package.string),
            CodingKeys.modules: .array(self.modules.map { .string($0.string) }),
        ]
    }
    public
    init(from json:JSON) throws 
    {
        self = try json.lint 
        {
            .init(
                package: try $0.remove(CodingKeys.package, as: String.self, 
                    PackageIdentifier.init(_:)),
                modules: try $0.remove(CodingKeys.modules, as: [JSON].self) 
                {
                    try $0.map { ModuleIdentifier.init(try $0.as(String.self)) }
                })
        }
    }
}

import PackagePlugin

#if os(Linux)
import Glibc
#elseif os(macOS)
import Darwin 
#endif

public
struct ToolError:Error 
{
    public
    enum Stage
    {
        case posix_spawn
        case waitpid
        case tool(String)
    }

    public 
    let stage:Stage 
    public 
    let status:Int32

    init(_ stage:Stage, status:Int32)
    {
        self.stage = stage
        self.status = status
    }
}
extension ToolError.Stage:CustomStringConvertible
{
    public 
    var description:String 
    {
        switch self
        {
        case .posix_spawn:      return "posix_spawn"
        case .waitpid:          return "waitpid"
        case .tool(let tool):   return tool
        }
    }
}
extension ToolError:CustomStringConvertible
{
    public 
    var description:String 
    {
        "\(self.stage.description) exited with code \(self.status)"
    }
}

extension PluginContext.Tool
{
    func run(arguments:String...) throws
    {
        try self.run(arguments: arguments)
    }
    func run(arguments:[String]) throws
    {
        let name:String = self.path.lastComponent
        try self.path.string.withCString 
        {
            (tool:UnsafePointer<CChar>) in 

            let arguments:[UnsafeMutablePointer<CChar>] = arguments.map
            {
                let bytes:Int = $0.utf8.count
                let argument:UnsafeMutablePointer<CChar> = .allocate(capacity: bytes + 1)
                for (offset, byte):(Int, UInt8) in $0.utf8.enumerated()
                {
                    (argument + offset).initialize(to: Int8.init(bitPattern: byte))
                }
                (argument + bytes).initialize(to: 0)
                return argument
            }
            defer
            {
                arguments.map { $0.deallocate() }
            }

            // must be null-terminated!
            let vector:[UnsafeMutablePointer<CChar>?] = 
            [
                .init(mutating: tool),
            ]
            +
            arguments.lazy.map(Optional.some(_:))
            +
            [
                nil
            ]

            var pid:pid_t = 0
            switch posix_spawn(&pid, tool, nil, nil, vector, nil)
            {
            case 0: 
                break 
            case let code: 
                throw ToolError.init(.posix_spawn, status: code)
            }
            var status:Int32 = 0
            switch waitpid(pid, &status, 0)
            {
            case pid: 
                break 
            case let code:
                throw ToolError.init(.waitpid, status: code)
            }
            guard status == 0 
            else 
            {
                throw ToolError.init(.tool(name), status: status)
            }
        }
    }
}
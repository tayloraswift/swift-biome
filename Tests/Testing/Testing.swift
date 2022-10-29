public
struct SourceLocation
{
    public
    let function:String
    public
    let file:String
    public
    let line:Int
    public
    let column:Int

    @inlinable public
    init(function:String, file:String, line:Int, column:Int)
    {
        self.function = function
        self.file = file
        self.line = line
        self.column = column        
    }
}
extension SourceLocation:CustomStringConvertible
{
    public
    var description:String
    {
        "\(file):\(line):\(column)"
    }
}


public
enum Assert
{
}

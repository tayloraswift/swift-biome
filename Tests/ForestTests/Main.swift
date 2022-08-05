import Forest 

@main 
struct Main 
{
    func assert(_ test:@autoclosure () throws -> Bool, 
        file:String = #file, 
        function:String = #function, 
        line:Int = #line, 
        column:Int = #column) rethrows 
    {
        guard try test() 
        else 
        {
            print("\(file):\(line):\(column): test failed")
            return
        }
    }

    static 
    func main() 
    {
        Self.init().main()
    }
    func main() 
    {
        var forest:Forest<Int> = .init()
        var tree:Forest<Int>.Tree.Head? = nil
        let elements:[Int] = (0 ..< 1024).shuffled()
        for element:Int in elements 
        {
            forest.insert(ordered: element, into: &tree)
        }

        self.assert(forest.count == 1024)
        self.assert(forest[tree].elementsEqual(0 ..< 1024))
        self.assert(forest[tree].validate())
    }
}
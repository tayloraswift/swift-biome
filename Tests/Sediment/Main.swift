import Testing

@main 
enum Main:SynchronousTests
{
    static 
    func run(tests:inout Tests)
    {
        for i:Int in 0 ..< 500
        {
            print("performing fuzzing iteration \(i)")
            tests.run()
        }
    }
}

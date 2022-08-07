import Forest 

@main 
struct Main
{
    static 
    func main() 
    {
        let clock:SuspendingClock = .init()
        print("shuffled:")
        print(Self.shuffled(clock,  elements: (0 ..< 1 << 20)))
        print("lifo:")
        print(Self.lifo(clock,      elements: (0 ..< 1 << 20)))
    }

    private static 
    func shuffled(_ clock:SuspendingClock, elements:some Sequence<Int>) -> (insert:Duration, remove:Duration)
    {
        let insertions:[Int] = elements.shuffled()
        let removals:[Int] = insertions.shuffled()

        var forest:Forest<Int> = .init(), 
            tree:Forest<Int>.Tree.Head? = nil
        let insert:Duration = clock.measure 
        {
            for element:Int in insertions
            {
                forest.insert(element, into: &tree)
            }
        }
        let remove:Duration = clock.measure 
        {
            for element:Int in removals
            {
                if let index:Forest<Int>.Index = forest[tree].find(element)
                {
                    forest.remove(index, from: &tree)
                }
            }
        }
        return (insert: insert, remove: remove)
    }
    private static 
    func lifo(_ clock:SuspendingClock, elements:some Sequence<Int>) -> (insert:Duration, remove:Duration)
    {
        var forest:Forest<Int> = .init(), 
            tree:Forest<Int>.Tree.Head? = nil
        let insert:Duration = clock.measure 
        {
            for element:Int in elements
            {
                forest.push(min: element, into: &tree)
            }
        }
        let remove:Duration = clock.measure 
        {
            while let index:Forest<Int>.Index = tree?.index
            {
                forest.remove(index, from: &tree)
            }
        }
        return (insert: insert, remove: remove)
    }
}
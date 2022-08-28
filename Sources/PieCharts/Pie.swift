import SVG 

public 
enum Pie 
{
    @frozen public 
    struct Sector 
    {
        public
        var weight:Int 
        public
        var classes:String

        @inlinable public 
        init(weight:Int, classes:String = "")
        {
            self.weight = weight 
            self.classes = classes 
        }

        func path(arc:(start:Point, end:Point), radians:Double, divisor:Double, 
            fringe:Point? = nil) 
            -> SVG.Element<Never> 
        {
            let width:Double = Double.init(self.weight) / divisor

            var d:String = "M 0,0 L \(arc.start)"
            if  width < 0.375
            {
                // minor arc 
                d += " A 1,1 0 0 0 \(arc.end)"
            }
            else if width > 0.625
            {
                // major arc 
                d += " A 1,1 0 1 0 \(arc.end)"
            }
            else 
            {
                // near-semicircular arc,
                // split into 2 segments to avoid degenerate behavior.
                let split:Point = .init(radians: radians - 0.5 * Double.pi)
                d += " A 1,1 0 0 0 \(split) A 1,1 0 0 0 \(arc.end)"
            }
            if let fringe:Point = fringe 
            {
                d += " L \(fringe) Z"
            }
            else 
            {
                d += "Z"
            }
            return .path(attributes: self.classes.isEmpty ? 
                [.d(d)] : [.d(d), .class(self.classes)])
        }
    }

    struct Point:CustomStringConvertible 
    {
        var x:Double 
        var y:Double 

        init(_ x:Double, _ y:Double)
        {
            self.x = x 
            self.y = y 
        }
        init(radians:Double, radius:Double = 1.0) 
        {
            self.init(radius * _cos(radians), radius * -_sin(radians))
        }

        var description:String
        {
            "\(self.x),\(self.y)"
        }
    }

    public static 
    func svg(_ sectors:[Sector]) -> SVG.Root<Never>
    {
        let divisor:Double = .init(sectors.reduce(0) { $0 + $1.weight })

        var start:Point = .init(1, 0)
        var accumulated:Int = 0 
        var paths:[SVG.Element<Never>] = []
            paths.reserveCapacity(sectors.count)
        for sector:Sector in sectors.dropLast() 
        {
            accumulated += sector.weight 

            let fraction:Double = Double.init(accumulated) / divisor, 
                radians:Double = 2 * Double.pi * fraction
            
            let end:Point = .init(radians: radians)
            var fringe:Point = .init(radians: radians + 0.1, radius: 0.5)
            // do not let the fringe get past the +x pole 
            if  fraction > 0.75
            {
                fringe.y = min(fringe.y, 0)
            }
            paths.append(sector.path(arc: (start, end), 
                radians: radians, 
                divisor: divisor, 
                fringe: fringe))
            start = end 
        }
        if let sector:Sector = sectors.last 
        {
            paths.append(sector.path(arc: (start, .init(1, 0)), 
                radians: 2 * Double.pi, 
                divisor: divisor))
        }
        return .init(.g(paths), attributes: [.viewBox("-1 -1 2 2")])
    }
}
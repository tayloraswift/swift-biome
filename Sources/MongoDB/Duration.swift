extension Duration
{
    var milliseconds:Int64
    {
        self.components.seconds     * 1_000 +
        self.components.attoseconds / 1_000_000_000_000_000
    }
}
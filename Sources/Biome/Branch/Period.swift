protocol TrunkPeriod
{
    /// The last version contained within this period.
    var latest:Version { get }
    /// The branch and revision this period was forked from, 
    /// if applicable.
    var fork:Version? { get }
}
extension TrunkPeriod 
{
    /// The index of the original branch this period was cut from.
    /// 
    /// This is the branch that contains the period, not the branch 
    /// the period was forked from.
    var branch:Version.Branch
    {
        self.latest.branch
    }
    /// The index of the last revision contained within this period.
    var limit:Version.Revision 
    {
        self.latest.revision
    }
    
    func version(before revision:Version.Revision) -> Version?
    {
        revision.predecessor.map { .init(self.branch, $0) } ?? self.fork
    }
}
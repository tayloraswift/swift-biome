import Versions 

extension Branch 
{
    struct Revisions:RandomAccessCollection, Sendable 
    {
        private 
        var revisions:[Revision]

        init() 
        {
            self.revisions = []
        }

        var startIndex:Version.Revision 
        {
            .init(.init(self.revisions.startIndex))
        }
        var endIndex:Version.Revision 
        {
            .init(.init(self.revisions.endIndex))
        }
        var indices:Range<Version.Revision> 
        {
            self.startIndex ..< self.endIndex
        }
        subscript(revision:Version.Revision) -> Revision
        {
            _read 
            {
                yield  self.revisions[.init(revision.offset)]
            }
            _modify
            {
                yield &self.revisions[.init(revision.offset)]
            }
        }
    }
}
extension Branch.Revisions 
{
    // FIXME: this could be made a lot more efficient assuming the dates are ordered 
    func find(_ date:Date) -> Version.Revision?
    {
        self.firstIndex { $0.date == date }
    }

    // FIXME: this could be made a lot more efficient
    func find(_ hash:String) -> Version.Revision?
    {
        self.firstIndex { $0.commit.hash == hash }
    }
}
extension Branch.Revisions:ExpressibleByArrayLiteral 
{
    init(arrayLiteral:Branch.Revision...)
    {
        self.revisions = arrayLiteral
    }
}
extension Branch.Revisions:RangeReplaceableCollection 
{
    mutating 
    func append(_ revision:Branch.Revision)
    {
        self.revisions.append(revision)
    }
    mutating 
    func replaceSubrange(_ range:Range<Version.Revision>, 
        with revisions:some Collection<Branch.Revision>)
    {
        let range:Range<Int> = 
            Int.init(range.lowerBound.offset) ..< 
            Int.init(range.upperBound.offset)
        self.revisions.replaceSubrange(range, with: revisions)
    }
}
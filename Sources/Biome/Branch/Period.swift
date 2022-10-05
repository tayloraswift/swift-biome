import Sediment

struct _Period<Axis> where Axis:PeriodAxis
{
    let axis:Axis
    /// The last version contained within this period.
    let latest:Version
    /// The branch and revision this period was forked from, 
    /// if applicable.
    let fork:Version?

    init(_ axis:Axis, latest:Version, fork:Version?)
    {
        self.axis = axis 
        self.latest = latest 
        self.fork = fork
    }
}
extension _Period
{
    /// The index of the original branch this period was cut from.
    /// 
    /// This is the branch that contains the period, not the branch 
    /// the period was forked from.
    var branch:Version.Branch
    {
        self.latest.branch
    }
}

extension _Period
{
    struct FieldView<Value> where Value:Equatable
    {
        let sediment:Sediment<Version.Revision, Value>
        let period:_Period<Axis>

        init(_ period:_Period<Axis>, sediment:Sediment<Version.Revision, Value>)
        {
            self.sediment = sediment
            self.period = period
        }
    }
}
extension _Period.FieldView
{
    var axis:Axis
    {
        self.period.axis
    }
    var fork:Version?
    {
        self.period.fork
    }
    var latest:Version
    {
        self.period.latest
    }
}
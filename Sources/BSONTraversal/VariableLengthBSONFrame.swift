public
protocol VariableLengthBSONFrame
{
    /// The number of (conceptual) bytes in the frame prefix of the type
    /// this frame type is associated with.
    /// This can be zero if the frame’s length header does not include its
    /// own length, and can be negative if the length header skips additional
    /// bytes before it starts counting.
    static
    var prefix:Int { get }

    /// The number of (conceptual) bytes in the frame suffix of the type
    /// this frame type is associated with.
    static
    var suffix:Int { get }
}

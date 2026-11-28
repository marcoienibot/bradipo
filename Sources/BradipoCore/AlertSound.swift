/// Picks which of the macOS alert sounds a break plays.
public enum AlertSound {
    /// The sound that plays for a saved name, which Settings shows as chosen: the saved sound, or else the default,
    /// or else the first sound there is. A name edited by hand, or one a later macOS no longer has, would otherwise
    /// play nothing while Settings showed it.
    /// - Parameters:
    ///   - saved: Nil or empty until a sound is chosen.
    ///   - available: The sounds macOS has, in the order Settings lists them.
    /// - Returns: Nil only when there are no sounds at all.
    public static func resolve(_ saved: String?, default fallback: String, among available: [String]) -> String? {
        if let saved, available.contains(saved) { return saved }
        return available.contains(fallback) ? fallback : available.first
    }
}

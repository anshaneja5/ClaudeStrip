import Foundation

/// Determines the "active" Claude Code session without hooks:
/// the session whose .jsonl was modified most recently.
public enum ActiveSession {

    public static var defaultProjectsRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")
    }

    /// Returns the session id (the .jsonl filename without extension) of the
    /// most-recently-modified session file under `projectsRoot`, or nil.
    public static func newestModifiedSessionId(projectsRoot: URL) -> String? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: projectsRoot,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var newestURL: URL?
        var newestDate = Date.distantPast
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            if date > newestDate {
                newestDate = date
                newestURL = url
            }
        }
        return newestURL?.deletingPathExtension().lastPathComponent
    }
}

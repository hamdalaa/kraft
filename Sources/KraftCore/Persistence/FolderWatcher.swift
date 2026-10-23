import Foundation

/// Calls `handler` (on the main queue) when a file in `directory` is added, replaced, renamed or
/// written in place. Watches the folder for atomic replaces (iCloud Drive, other Kraft processes)
/// and the file itself for in-place writes; the file source is re-armed after every replace.
public final class FolderWatcher: @unchecked Sendable {
    private let directory: URL
    private let file: URL
    private let handler: @MainActor () -> Void
    private var folderSource: (any DispatchSourceFileSystemObject)?
    private var fileSource: (any DispatchSourceFileSystemObject)?

    public init(directory: URL, file: URL, handler: @escaping @MainActor () -> Void) {
        self.directory = directory
        self.file = file
        self.handler = handler
        folderSource = Self.source(for: directory, events: [.write, .rename, .delete]) { [weak self] in self?.fire() }
        armFile()
    }

    deinit { cancel() }

    public func cancel() {
        folderSource?.cancel()
        fileSource?.cancel()
        folderSource = nil
        fileSource = nil
    }

    private func fire() {
        armFile()
        MainActor.assumeIsolated { handler() }
    }

    private func armFile() {
        fileSource?.cancel()
        fileSource = Self.source(for: file, events: [.write, .extend, .delete, .rename]) { [weak self] in self?.fire() }
    }

    private static func source(
        for url: URL, events: DispatchSource.FileSystemEvent, handler: @escaping @Sendable () -> Void
    ) -> (any DispatchSourceFileSystemObject)? {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: events, queue: .main)
        source.setEventHandler(handler: handler)
        source.setCancelHandler { close(fd) }
        source.resume()
        return source
    }
}

import Foundation

/// Where the speech model comes from and where Said keeps it.
enum ModelStore {
    static let fileName = "ggml-small.en.bin"
    static let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin")!
    /// Size of the published file, used for the progress bar until the server says otherwise.
    static let expectedBytes: Int64 = 487_614_201

    static var destination: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Said/\(fileName)")
    }

    static var isInstalled: Bool { Transcriber.defaultModelPath() != nil }
}

/// Downloads the speech model once, reporting progress on the main queue.
final class ModelDownload: NSObject, URLSessionDownloadDelegate {
    var onProgress: ((_ received: Int64, _ total: Int64) -> Void)?
    var onFinish: ((_ error: Error?) -> Void)?
    private(set) var isRunning = false
    private var session: URLSession?
    private var moveError: Error?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        moveError = nil
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        session.downloadTask(with: ModelStore.url).resume()
        self.session = session
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : ModelStore.expectedBytes
        onProgress?(totalBytesWritten, total)
    }

    // The temporary file is deleted when this returns, so it has to be moved here.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
                throw DownloadError.server(http.statusCode)
            }
            let size = (try FileManager.default.attributesOfItem(atPath: location.path)[.size] as? NSNumber)?.int64Value ?? 0
            let expected = downloadTask.countOfBytesExpectedToReceive
            if expected > 0, size != expected { throw DownloadError.incomplete }
            let destination = ModelStore.destination
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            moveError = error
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        isRunning = false
        session.finishTasksAndInvalidate()
        self.session = nil
        let failure = error ?? moveError
        Trace.log("model download: \(failure.map { "failed, \($0.localizedDescription)" } ?? "done")")
        onFinish?(failure)
    }

    enum DownloadError: Error { case server(Int), incomplete }
}

import Foundation
import Combine

/// モデルのダウンロード状態
enum ModelDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case bundled  // アプリバンドルに含まれている
    case failed(String)

    static func == (lhs: ModelDownloadState, rhs: ModelDownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.notDownloaded, .notDownloaded): return true
        case (.downloaded, .downloaded): return true
        case (.bundled, .bundled): return true
        case let (.downloading(a), .downloading(b)): return a == b
        case let (.failed(a), .failed(b)): return a == b
        default: return false
        }
    }

    var isAvailable: Bool {
        switch self {
        case .downloaded, .bundled: return true
        default: return false
        }
    }
}

/// ダウンロード可能なモデルの情報
struct DownloadableModel {
    let fileName: String
    let fileExtension: String  // "mlmodelc" or "mlpackage"
    let downloadURL: URL?
    let estimatedSizeMB: Int
}

/// モデルのダウンロードと管理を行うマネージャー
final class ModelDownloadManager: ObservableObject {
    static let shared = ModelDownloadManager()

    /// モデルごとのダウンロード状態
    @Published var modelStates: [String: ModelDownloadState] = [:]

    /// ダウンロードしたモデルの保存先ディレクトリ
    private let modelsDirectory: URL

    /// ベースURL（自前サーバーまたはCDN）
    /// 実際の運用時にはここを自分のサーバーURLに変更してください
    private let baseDownloadURL: URL?

    private var downloadTasks: [String: URLSessionDownloadTask] = [:]

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        modelsDirectory = caches.appendingPathComponent("MLModels", isDirectory: true)

        // ダウンロードディレクトリを作成
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        // ベースURL（将来的にサーバーを用意する場合ここを変更）
        baseDownloadURL = nil  // 未設定時はダウンロード不可

        // 初期状態をスキャン
        refreshAllStates()
    }

    // MARK: - Model Availability

    /// モデルファイルのURLを返す（バンドル優先、次にダウンロード済み）
    func modelURL(fileName: String, fileExtension: String = "mlmodelc") -> URL? {
        // 1. バンドル内をチェック
        if let bundleURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension) {
            return bundleURL
        }

        // 2. ダウンロード済みをチェック
        let downloadedURL = modelsDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension(fileExtension)
        if FileManager.default.fileExists(atPath: downloadedURL.path) {
            return downloadedURL
        }

        return nil
    }

    /// モデルの状態を取得
    func state(for fileName: String) -> ModelDownloadState {
        modelStates[fileName] ?? .notDownloaded
    }

    /// 全モデルの状態を更新
    func refreshAllStates() {
        // YOLO variants
        for variant in YOLOVariant.allCases {
            updateState(for: variant.modelFileName, fileExtension: "mlmodelc")
        }
        // Depth variants
        for variant in DepthModelVariant.allCases {
            updateState(for: variant.modelFileName, fileExtension: "mlmodelc")
        }
        // Segmentation variants
        for variant in SegmentationModelVariant.allCases {
            updateState(for: variant.modelFileName, fileExtension: "mlmodelc")
        }
    }

    private func updateState(for fileName: String, fileExtension: String) {
        if Bundle.main.url(forResource: fileName, withExtension: fileExtension) != nil {
            modelStates[fileName] = .bundled
        } else {
            let downloadedURL = modelsDirectory
                .appendingPathComponent(fileName)
                .appendingPathExtension(fileExtension)
            if FileManager.default.fileExists(atPath: downloadedURL.path) {
                modelStates[fileName] = .downloaded
            } else {
                // 既存のダウンロード中状態は維持
                if case .downloading = modelStates[fileName] {
                    return
                }
                modelStates[fileName] = .notDownloaded
            }
        }
    }

    // MARK: - Download

    /// モデルをダウンロード（将来的にサーバーを用意した場合に使用）
    func downloadModel(fileName: String, from url: URL, fileExtension: String = "mlmodelc") {
        guard downloadTasks[fileName] == nil else { return }

        DispatchQueue.main.async {
            self.modelStates[fileName] = .downloading(progress: 0)
        }

        let session = URLSession(
            configuration: .default,
            delegate: DownloadDelegate(manager: self, fileName: fileName, fileExtension: fileExtension),
            delegateQueue: nil
        )

        let task = session.downloadTask(with: url)
        downloadTasks[fileName] = task
        task.resume()
    }

    /// ダウンロードをキャンセル
    func cancelDownload(fileName: String) {
        downloadTasks[fileName]?.cancel()
        downloadTasks[fileName] = nil
        DispatchQueue.main.async {
            self.modelStates[fileName] = .notDownloaded
        }
    }

    /// ダウンロード済みモデルを削除
    func deleteDownloadedModel(fileName: String, fileExtension: String = "mlmodelc") {
        let url = modelsDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension(fileExtension)
        try? FileManager.default.removeItem(at: url)
        DispatchQueue.main.async {
            self.modelStates[fileName] = .notDownloaded
        }
    }

    /// ダウンロード済みモデルの合計サイズ（MB）
    var downloadedModelsSizeMB: Int {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: modelsDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        return Int(totalSize / (1024 * 1024))
    }

    // MARK: - Internal

    fileprivate func handleDownloadCompletion(
        fileName: String,
        fileExtension: String,
        tempURL: URL?,
        error: Error?
    ) {
        downloadTasks[fileName] = nil

        if let error {
            DispatchQueue.main.async {
                self.modelStates[fileName] = .failed(error.localizedDescription)
            }
            return
        }

        guard let tempURL else {
            DispatchQueue.main.async {
                self.modelStates[fileName] = .failed("ダウンロードファイルが見つかりません")
            }
            return
        }

        let destination = modelsDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension(fileExtension)

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tempURL, to: destination)
            DispatchQueue.main.async {
                self.modelStates[fileName] = .downloaded
            }
        } catch {
            DispatchQueue.main.async {
                self.modelStates[fileName] = .failed(error.localizedDescription)
            }
        }
    }

    fileprivate func handleDownloadProgress(fileName: String, progress: Double) {
        DispatchQueue.main.async {
            self.modelStates[fileName] = .downloading(progress: progress)
        }
    }
}

// MARK: - URLSession Download Delegate

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    weak var manager: ModelDownloadManager?
    let fileName: String
    let fileExtension: String

    init(manager: ModelDownloadManager, fileName: String, fileExtension: String) {
        self.manager = manager
        self.fileName = fileName
        self.fileExtension = fileExtension
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        manager?.handleDownloadCompletion(
            fileName: fileName,
            fileExtension: fileExtension,
            tempURL: location,
            error: nil
        )
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            manager?.handleDownloadCompletion(
                fileName: fileName,
                fileExtension: fileExtension,
                tempURL: nil,
                error: error
            )
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        manager?.handleDownloadProgress(fileName: fileName, progress: progress)
    }
}

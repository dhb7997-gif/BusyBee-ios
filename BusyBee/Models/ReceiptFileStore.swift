import Foundation
import UIKit

enum ReceiptFileStoreError: Error {
    case writeFailed
    case readFailed
    case deleteFailed
    case imageTooLarge
    case insufficientStorage
    case directoryAccessFailed
}

actor ReceiptFileStore {
    static let shared = ReceiptFileStore()

    private let fileManager = FileManager.default
    private let maxImageSizeBytes: Int = 10 * 1024 * 1024 // 10MB
    private let minRequiredStorageBytes: Int64 = 50 * 1024 * 1024 // 50MB minimum free space

    private var receiptsDirectory: URL? {
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        var directory = base.appendingPathComponent("Receipts", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? directory.setResourceValues(resourceValues)
        }
        return directory
    }

    func save(image: UIImage, for expenseID: UUID) throws {
        // Check directory access
        guard let directory = receiptsDirectory else {
            throw ReceiptFileStoreError.directoryAccessFailed
        }

        // Check available storage space
        if let availableSpace = try? directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage {
            if availableSpace < minRequiredStorageBytes {
                throw ReceiptFileStoreError.insufficientStorage
            }
        }

        // Try to get image data with progressive compression
        var compressionQuality: CGFloat = 0.9
        var data = image.jpegData(compressionQuality: compressionQuality)

        // If initial data is too large, progressively compress
        while let imageData = data, imageData.count > maxImageSizeBytes && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            data = image.jpegData(compressionQuality: compressionQuality)
        }

        guard let finalData = data else {
            throw ReceiptFileStoreError.writeFailed
        }

        // Final check - if still too large after maximum compression, reject
        if finalData.count > maxImageSizeBytes {
            throw ReceiptFileStoreError.imageTooLarge
        }

        let url = urlForReceipt(id: expenseID, in: directory)
        do {
            try finalData.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            throw ReceiptFileStoreError.writeFailed
        }
    }

    func load(for expenseID: UUID) throws -> UIImage {
        guard let directory = receiptsDirectory else {
            throw ReceiptFileStoreError.directoryAccessFailed
        }
        let url = urlForReceipt(id: expenseID, in: directory)
        guard fileManager.fileExists(atPath: url.path) else { throw ReceiptFileStoreError.readFailed }
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
            throw ReceiptFileStoreError.readFailed
        }
        return image
    }

    func delete(for expenseID: UUID) {
        guard let directory = receiptsDirectory else { return }
        let url = urlForReceipt(id: expenseID, in: directory)
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    func receiptExists(for expenseID: UUID) -> Bool {
        guard let directory = receiptsDirectory else { return false }
        return fileManager.fileExists(atPath: urlForReceipt(id: expenseID, in: directory).path)
    }

    private func urlForReceipt(id: UUID, in directory: URL) -> URL {
        directory.appendingPathComponent("\(id.uuidString).jpg")
    }
}

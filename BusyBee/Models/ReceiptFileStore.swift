import Foundation
import UIKit

enum ReceiptFileStoreError: Error {
    case writeFailed
    case readFailed
    case deleteFailed
}

actor ReceiptFileStore {
    static let shared = ReceiptFileStore()

    private let fileManager = FileManager.default
    private var receiptsDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
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
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw ReceiptFileStoreError.writeFailed
        }
        let url = urlForReceipt(id: expenseID)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ReceiptFileStoreError.writeFailed
        }
    }

    func load(for expenseID: UUID) throws -> UIImage {
        let url = urlForReceipt(id: expenseID)
        guard fileManager.fileExists(atPath: url.path) else { throw ReceiptFileStoreError.readFailed }
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
            throw ReceiptFileStoreError.readFailed
        }
        return image
    }

    func delete(for expenseID: UUID) {
        let url = urlForReceipt(id: expenseID)
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    func receiptExists(for expenseID: UUID) -> Bool {
        fileManager.fileExists(atPath: urlForReceipt(id: expenseID).path)
    }

    private func urlForReceipt(id: UUID) -> URL {
        receiptsDirectory.appendingPathComponent("\(id.uuidString).jpg")
    }
}

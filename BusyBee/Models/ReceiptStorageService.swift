import Foundation
import UIKit

struct ReceiptStorageService {
    static func save(image: UIImage, for expenseID: UUID) async throws {
        try await ReceiptFileStore.shared.save(image: image, for: expenseID)
    }

    static func load(for expenseID: UUID) async -> UIImage? {
        try? await ReceiptFileStore.shared.load(for: expenseID)
    }

    static func delete(for expenseID: UUID) async {
        await ReceiptFileStore.shared.delete(for: expenseID)
    }

    static func exists(for expenseID: UUID) async -> Bool {
        await ReceiptFileStore.shared.receiptExists(for: expenseID)
    }
}

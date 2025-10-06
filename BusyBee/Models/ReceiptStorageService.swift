import Foundation
import Photos
import UIKit

enum ReceiptStorageResult {
    case success
    case denied
    case failure(Error)
}

struct ReceiptStorageService {
    static func save(image: UIImage, completion: @escaping (ReceiptStorageResult) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            performSave(image: image, completion: completion)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        performSave(image: image, completion: completion)
                    } else {
                        completion(.denied)
                    }
                }
            }
        default:
            completion(.denied)
        }
    }

    private static func performSave(image: UIImage, completion: @escaping (ReceiptStorageResult) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(error))
                } else if success {
                    completion(.success)
                } else {
                    completion(.failure(NSError(domain: "ReceiptStorage", code: -1, userInfo: nil)))
                }
            }
        }
    }
}

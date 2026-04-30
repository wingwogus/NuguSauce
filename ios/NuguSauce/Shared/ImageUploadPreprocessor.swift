import Foundation
import UIKit

enum ImageUploadPreprocessor {
    static func normalizedJPEGData(
        from data: Data,
        maxDimension: CGFloat,
        compressionQuality: CGFloat = 0.82
    ) -> Data {
        guard let image = UIImage(data: data) else {
            return data
        }
        let resizedImage = image.resizedForUpload(maxDimension: maxDimension)
        return resizedImage.jpegData(compressionQuality: compressionQuality) ?? data
    }
}

private extension UIImage {
    func resizedForUpload(maxDimension: CGFloat) -> UIImage {
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else {
            return self
        }

        let scale = maxDimension / largestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

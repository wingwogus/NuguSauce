import Foundation
import UIKit

enum ImageUploadPreprocessor {
    static let defaultMaxBytes = 5 * 1024 * 1024

    static func normalizedJPEGData(
        from data: Data,
        maxDimension: CGFloat,
        compressionQuality: CGFloat = 0.82,
        maxBytes: Int = defaultMaxBytes
    ) -> Data {
        guard let image = UIImage(data: data),
              maxDimension > 0,
              maxBytes > 0 else {
            return data
        }

        let largestSide = max(image.size.width, image.size.height)
        guard largestSide > 0 else {
            return data
        }

        var targetDimension = min(maxDimension, largestSide)
        var smallestEncodedData: Data?
        let qualitySteps = jpegQualitySteps(startingAt: compressionQuality)

        while true {
            let resizedImage = image.resizedForUpload(maxDimension: targetDimension)
            for quality in qualitySteps {
                guard let encodedData = resizedImage.jpegData(compressionQuality: quality) else {
                    continue
                }
                if encodedData.count <= maxBytes {
                    return encodedData
                }
                if smallestEncodedData == nil || encodedData.count < smallestEncodedData!.count {
                    smallestEncodedData = encodedData
                }
            }

            let nextDimension = targetDimension * 0.75
            guard nextDimension >= 320, nextDimension < targetDimension else {
                break
            }
            targetDimension = nextDimension
        }

        return smallestEncodedData ?? data
    }

    private static func jpegQualitySteps(startingAt quality: CGFloat) -> [CGFloat] {
        let candidates: [CGFloat] = [quality, 0.74, 0.66, 0.58, 0.50, 0.42, 0.34, 0.26, 0.20]
        var seenBuckets: Set<Int> = []
        return candidates.compactMap { candidate in
            let clamped = min(max(candidate, 0.20), 1.0)
            let bucket = Int((clamped * 100).rounded())
            guard seenBuckets.insert(bucket).inserted else {
                return nil
            }
            return clamped
        }
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
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

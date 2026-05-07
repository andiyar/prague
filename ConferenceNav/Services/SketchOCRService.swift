import Foundation
import Vision
import UIKit

enum SketchOCR {
    /// Runs Vision text recognition over the image and returns concatenated text.
    /// Returns nil if recognition fails or produces no text.
    static func transcribe(image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("SketchOCR: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Sort by reading order: top-to-bottom, left-to-right.
                // Vision returns normalized coordinates with origin at bottom-left,
                // so larger y means higher on the page — sort y descending.
                let sorted = observations.sorted { a, b in
                    let aTop = a.boundingBox.maxY
                    let bTop = b.boundingBox.maxY
                    if abs(aTop - bTop) > 0.04 { return aTop > bTop }   // different lines
                    return a.boundingBox.minX < b.boundingBox.minX       // same line, left-to-right
                }

                // Drop very-low-confidence observations entirely. Vision happily
                // emits stray marks ("_", "-", ":") with sub-0.3 confidence —
                // they end up polluting the note body otherwise.
                let lines = sorted.compactMap { obs -> String? in
                    guard let top = obs.topCandidates(1).first else { return nil }
                    if top.confidence < 0.3 { return nil }
                    return top.string
                }
                let combined = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

                // Reject the whole transcription if it has fewer than 2
                // alphanumeric characters — almost certainly a misread mark
                // rather than real handwritten text. Better to insert nothing
                // than insert a stray "_" the user has to clean up.
                let alphanumericCount = combined.unicodeScalars.reduce(0) {
                    $0 + (CharacterSet.alphanumerics.contains($1) ? 1 : 0)
                }
                if alphanumericCount < 2 {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: combined.isEmpty ? nil : combined)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-GB", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    print("SketchOCR: handler failed \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

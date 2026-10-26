import SwiftUI
import UIKit

@MainActor final class DemoModel: ObservableObject {
    @Published var mode: BakeryMode = .binary { didSet { cancel() } }
    @Published var fixture = false { didSet { reset() } }
    @Published var photo: UIImage?
    @Published var photoLabel = "CAPTURED STILL"
    @Published var busy = false
    @Published var decision: BakeryDecision?
    @Published var error: String?
    @Published var seconds: Double?
    @Published var apiMilliseconds: Double?
    @Published var raw = ""
    @Published var hasKey = KeychainStore.read() != nil
    @Published var challenge = ""
    private var task: Task<Void,Never>?
    private var revision = UUID()
    private var capturedAt: Date?
    private var jpeg: Data?
    var ready: Bool { fixture || (jpeg != nil && hasKey) }
    func cancel() {
        revision = UUID(); task?.cancel(); task = nil; busy = false
        decision = nil; seconds = nil; apiMilliseconds = nil; raw = ""; error = nil
    }
    func reset() { cancel(); photo = nil; jpeg = nil; capturedAt = nil; challenge = "" }
    func setPhoto(_ image: UIImage, label:String = "CAPTURED STILL") {
        reset()
        // Shape/count checks need a compact frame, not a full-resolution photo upload.
        let maxSize: CGFloat = 512
        let scale = min(1,maxSize / max(image.size.width,image.size.height))
        let size = CGSize(width:image.size.width * scale,height:image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let resized = UIGraphicsImageRenderer(size:size,format:format).image { _ in image.draw(in:CGRect(origin:.zero,size:size)) }
        guard let data = resized.jpegData(compressionQuality:0.4), data.count <= 3_000_000 else { error = "Could not prepare that image."; return }
        photo = resized; photoLabel = label; jpeg = data; capturedAt = Date()
    }
    func submitPhoto(_ image: UIImage, label:String = "CAPTURED STILL") {
        setPhoto(image,label:label)
        guard photo != nil, error == nil else { return }
        decide()
    }
    func decide() {
        cancel()
        if fixture { accept(DecisionPolicy.fixture(mode),seconds:nil); return }
        guard let jpeg, let capturedAt else { error = "Capture a still or choose a photo first."; return }
        guard Date().timeIntervalSince(capturedAt) <= 60 else { error = "This still is over 60 seconds old. Retake or choose it again."; return }
        guard let key = KeychainStore.read() else { hasKey = false; error = "Add your demo API key in Settings first."; return }
        let token = revision; let selectedMode = mode
        busy = true
        task = Task {
            do {
                let result = try await DecisionClient.evaluate(mode:selectedMode,jpeg:jpeg,key:key)
                guard !Task.isCancelled, token == revision else { return }
                accept(result.response,seconds:result.seconds)
                if let value = result.serverMs.flatMap(Double.init), value.isFinite, value >= 0 { apiMilliseconds = value }

            } catch {
                guard !Task.isCancelled, token == revision else { return }
                self.error = (error as? URLError)?.code == .timedOut ? "API request timed out. Retake and retry, or choose fixtures." : (error as? DemoError)?.errorDescription ?? "Connection failed. No decision produced."
            }
            if token == revision {
                busy = false
                if selectedMode == .crowd { photo = nil; self.jpeg = nil; self.capturedAt = nil }
            }
        }
    }
    private func accept(_ response: DecisionResponse, seconds:Double?) {
        decision = DecisionPolicy.route(mode,response); self.seconds = seconds
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        raw = (try? encoder.encode(response)).flatMap { String(data:$0,encoding:.utf8) } ?? ""
    }
    func saveKey(_ value: String) throws {
        let key = value.trimmingCharacters(in:.whitespacesAndNewlines)
        guard key.hasPrefix("sk-"), key.count > 20, !key.contains(where: { $0.isWhitespace }) else { throw DemoError.message("Enter a valid OpenAI API key. It will not be shown after saving.") }
        try KeychainStore.save(key); hasKey = true; cancel()
        Task { await DecisionClient.prepareConnection() }
    }
    func removeKey() throws { try KeychainStore.remove(); hasKey = false; cancel() }
}

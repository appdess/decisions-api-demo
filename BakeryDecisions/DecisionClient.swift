import Foundation

struct TransportTiming: Codable {
    var protocolName: String?
    var reusedConnection: Bool
    var dnsMs: Double?
    var connectMs: Double?
    var tlsMs: Double?
    var uploadMs: Double?
    var waitMs: Double?
    var downloadMs: Double?
    var taskMs: Double
}
final class NoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var timing: TransportTiming?
    func snapshot() -> TransportTiming? { lock.lock(); defer { lock.unlock() }; return timing }
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        func ms(_ start:Date?,_ end:Date?) -> Double? { guard let start,let end else { return nil }; return end.timeIntervalSince(start) * 1000 }
        guard let t = metrics.transactionMetrics.last else { return }
        let value = TransportTiming(protocolName:t.networkProtocolName,reusedConnection:t.isReusedConnection,dnsMs:ms(t.domainLookupStartDate,t.domainLookupEndDate),connectMs:ms(t.connectStartDate,t.connectEndDate),tlsMs:ms(t.secureConnectionStartDate,t.secureConnectionEndDate),uploadMs:ms(t.requestStartDate,t.requestEndDate),waitMs:ms(t.requestEndDate,t.responseStartDate),downloadMs:ms(t.responseStartDate,t.responseEndDate),taskMs:metrics.taskInterval.duration * 1000)
        lock.lock(); timing = value; lock.unlock()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
struct LiveResult { let response: DecisionResponse; let seconds: Double; let requestID: String?; let timing: TransportTiming?; let bodyBytes: Int; let serverMs: String? }
enum DecisionClient {
    // One ephemeral session retains TLS/HTTP connections, not credentials or responses.
    // Every task has its own metrics delegate and Authorization header.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12; config.timeoutIntervalForResource = 15
        config.urlCache = nil; config.httpCookieStorage = nil
        return URLSession(configuration:config)
    }()
    @MainActor private static var preparedConnection = false
    @MainActor static func prepareConnection() async {
        guard !preparedConnection else { return }
        preparedConnection = true
        // Establish HTTPS while the camera opens. HEAD sends no key, photo or model request.
        var request = URLRequest(url:URL(string:"https://api.openai.com/v1/decisions")!)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        _ = try? await session.data(for:request,delegate:NoRedirect())
    }
    static func evaluate(mode: BakeryMode, jpeg: Data, key: String) async throws -> LiveResult {
        let delegate = NoRedirect()
        var request = URLRequest(url:URL(string:"https://api.openai.com/v1/decisions")!)
        request.httpMethod = "POST"; request.setValue("Bearer \(key)",forHTTPHeaderField:"Authorization"); request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.httpBody = try DecisionPolicy.request(mode,jpeg:jpeg)
        let start = ProcessInfo.processInfo.systemUptime
        let (data, response) = try await session.data(for:request,delegate:delegate)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw DemoError.message(status == 401 ? "API key rejected. Update your demo key in Settings." : status == 429 ? "API limit reached. Wait, then retry or use fixtures." : "API returned HTTP \(status). No decision produced.")
        }
        guard data.count < 1_000_000 else { throw DemoError.message("Unexpected API response size.") }
        let decoded: DecisionResponse
        do { decoded = try JSONDecoder().decode(DecisionResponse.self,from:data) }
        catch { throw DemoError.message("Unexpected API response. No decision produced.") }
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        #if DEBUG
        // Local profiling evidence only: never persist the photo, body, headers or key.
        if let timing = delegate.snapshot(), let timingData = try? JSONEncoder().encode(timing),
           let phases = try? JSONSerialization.jsonObject(with:timingData) {
            let report: [String:Any] = ["transport":phases,"requestBytes":request.httpBody?.count ?? 0,"jpegBytes":jpeg.count,"roundTripMs":elapsed*1000,"serverMs":http.value(forHTTPHeaderField:"openai-processing-ms") ?? "unavailable","requestID":http.value(forHTTPHeaderField:"x-request-id") ?? "unavailable"]
            if let data = try? JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),
               let folder = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask).first {
                try? data.write(to:folder.appendingPathComponent("latency-last.json"),options:.atomic)
            }
        }
        #endif
        return LiveResult(response:decoded,seconds:elapsed,requestID:http.value(forHTTPHeaderField:"x-request-id"),timing:delegate.snapshot(),bodyBytes:request.httpBody?.count ?? 0,serverMs:http.value(forHTTPHeaderField:"openai-processing-ms"))
    }
}

import Foundation

/// DiagTrace：关键路径环形缓冲（最近 40 步），崩溃时随报告一起提交
enum DiagTrace {
    private static var steps: [String] = []
    private static let lock = NSLock()

    static func step(_ text: String) {
        lock.lock()
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        steps.append("\(f.string(from: Date())) \(text)")
        if steps.count > 40 { steps.removeFirst(steps.count - 40) }
        lock.unlock()
    }

    static func dump() -> String {
        lock.lock()
        defer { lock.unlock() }
        return steps.joined(separator: "\n")
    }
}

/// CrashReporter：未捕获异常 → POST 到 api/requirement/save（type=bug修正, level=紧急）
/// 每个进程只报一次，最多等 2.5 秒，不阻塞用户
enum CrashReporter {

    private static var reported = false
    private static let lock = NSLock()

    static func install() {
        NSSetUncaughtExceptionHandler(crashHandler)
    }

    static func report(name: String, reason: String, symbols: String) {
        lock.lock()
        if reported { lock.unlock(); return }
        reported = true
        lock.unlock()

        let prefs = Prefs.shared
        guard prefs.userId != 0, !prefs.baseUrl.isEmpty else { return }
        let trace = DiagTrace.dump()
        let content = """
        [iOS崩溃] \(name): \(reason)
        构建: \(BuildInfo.tag)
        \(symbols)

        关键路径:
        \(trace)
        """
        let body: Json = [
            "type": "bug修正",
            "level": "紧急",
            "content": content,
            "userId": prefs.userId,
            "submitter": prefs.username,
        ]
        let api = ApiClient(baseUrl: prefs.baseUrl)
        api.userId = prefs.userId
        api.authToken = prefs.authToken.isEmpty ? nil : prefs.authToken
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            _ = try? await api.postJson("api/requirement/save", body)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2.5)
    }
}

enum BuildInfo {
    /// 构建标识（MMdd-HHmmss），出现在崩溃反馈标题里
    static let tag: String = {
        let f = DateFormatter()
        f.dateFormat = "MMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }()
}

/// 未捕获异常入口：C 函数指针不能捕获上下文，故用顶层函数转调
private func crashHandler(_ exception: NSException) {
    CrashReporter.report(
        name: exception.name.rawValue,
        reason: exception.reason ?? "",
        symbols: exception.callStackSymbols.joined(separator: "\n")
    )
}

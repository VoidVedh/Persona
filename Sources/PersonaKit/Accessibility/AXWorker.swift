import ApplicationServices
import Foundation

/// Dedicated background thread for handling Accessibility API calls and observer run loops.
/// Ensures hung target applications can never freeze the main AppKit UI thread.
public final class AXWorker {
    public static let shared = AXWorker()

    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private let semaphore = DispatchSemaphore(value: 0)
    private var isRunning = false

    public init() {
        start()
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        let t = Thread { [weak self] in
            guard let self = self else { return }
            self.runLoop = CFRunLoopGetCurrent()

            // Set system-wide AX messaging timeout to 250ms
            let systemWide = AXUIElementCreateSystemWide()
            AXUIElementSetMessagingTimeout(systemWide, 0.25)

            // Add dummy source to keep run loop alive
            var context = CFRunLoopSourceContext()
            let source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)

            self.semaphore.signal()
            CFRunLoopRun()
        }
        t.name = "dev.persona.mode.axworker"
        t.qualityOfService = .userInteractive
        t.start()
        self.thread = t

        _ = semaphore.wait(timeout: .now() + 2.0)
    }

    public func stop() {
        guard isRunning, let rl = runLoop else { return }
        CFRunLoopStop(rl)
        isRunning = false
        runLoop = nil
        thread = nil
    }

    public var targetRunLoop: CFRunLoop? {
        runLoop
    }

    /// Dispatches a block asynchronously onto the AXWorker thread.
    public func perform(_ block: @escaping @Sendable () -> Void) {
        guard let rl = runLoop else {
            DispatchQueue.global(qos: .userInteractive).async(execute: block)
            return
        }
        CFRunLoopPerformBlock(rl, CFRunLoopMode.defaultMode.rawValue) {
            block()
        }
        CFRunLoopWakeUp(rl)
    }

    /// Dispatches a block synchronously onto the AXWorker thread and returns its result.
    public func performSync<T>(_ block: @escaping () throws -> T) throws -> T {
        guard let rl = runLoop, CFRunLoopGetCurrent() !== rl else {
            return try block()
        }

        var result: Result<T, Error>?
        let sema = DispatchSemaphore(value: 0)

        CFRunLoopPerformBlock(rl, CFRunLoopMode.defaultMode.rawValue) {
            do {
                let value = try block()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
            sema.signal()
        }
        CFRunLoopWakeUp(rl)

        _ = sema.wait(timeout: .now() + 1.0)
        switch result {
        case .success(let val):
            return val
        case .failure(let err):
            throw err
        case .none:
            return try block()
        }
    }
}

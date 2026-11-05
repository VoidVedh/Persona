import Foundation
import WebKit

/// Serves `persona://app/...` assets in-memory using `WebUIRouter`.
public final class WebUISchemeHandler: NSObject, WKURLSchemeHandler {
    private let resourcesRootProvider: () -> URL?
    private let userDirsProvider: () -> WebUIRouter.UserDirs
    private let iconCache: IconCache
    private let lock = NSLock()
    private var activeTasks = Set<ObjectIdentifier>()

    public init(
        resourcesRootProvider: @escaping () -> URL? = { ResourceLocator.resourceDirectory() },
        userDirsProvider: @escaping () -> WebUIRouter.UserDirs = { .standard() },
        iconCache: IconCache = .shared
    ) {
        self.resourcesRootProvider = resourcesRootProvider
        self.userDirsProvider = userDirsProvider
        self.iconCache = iconCache
        super.init()
    }

    public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask as AnyObject)
        lock.lock()
        activeTasks.insert(taskID)
        lock.unlock()

        defer {
            lock.lock()
            activeTasks.remove(taskID)
            lock.unlock()
        }

        guard isTaskActive(taskID) else { return }

        guard let url = urlSchemeTask.request.url,
              url.scheme?.lowercased() == "persona",
              url.host?.lowercased() == "app",
              let root = resourcesRootProvider() else {
            fail(task: urlSchemeTask, taskID: taskID, statusCode: 404)
            return
        }

        guard let resolved = WebUIRouter.resolve(
            path: url.path,
            resourcesRoot: root,
            userDirs: userDirsProvider(),
            iconCache: iconCache
        ) else {
            fail(task: urlSchemeTask, taskID: taskID, statusCode: 404)
            return
        }

        guard isTaskActive(taskID) else { return }

        if let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: resolved.headers
        ) {
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(resolved.data)
            urlSchemeTask.didFinish()
        } else {
            let fallbackResponse = URLResponse(
                url: url,
                mimeType: resolved.mimeType,
                expectedContentLength: resolved.data.count,
                textEncodingName: "utf-8"
            )
            urlSchemeTask.didReceive(fallbackResponse)
            urlSchemeTask.didReceive(resolved.data)
            urlSchemeTask.didFinish()
        }
    }

    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask as AnyObject)
        lock.lock()
        activeTasks.remove(taskID)
        lock.unlock()
    }

    private func isTaskActive(_ taskID: ObjectIdentifier) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeTasks.contains(taskID)
    }

    private func fail(task: WKURLSchemeTask, taskID: ObjectIdentifier, statusCode: Int) {
        guard isTaskActive(taskID) else { return }
        if let url = task.request.url,
           let resp = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/plain"]) {
            task.didReceive(resp)
            task.didReceive(Data("Not Found".utf8))
            task.didFinish()
        } else {
            task.didFailWithError(NSError(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist))
        }
    }
}


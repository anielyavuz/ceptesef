import UIKit
import Social
import MobileCoreServices

class ShareViewController: UIViewController {
    private let appGroupId = "group.com.turneight.ceptesef"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleSharedItems()
    }

    private func handleSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            close()
            return
        }

        let group = DispatchGroup()
        var sharedItems: [[String: Any]] = []

        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else { continue }

            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { [weak self] item, error in
                        defer { group.leave() }
                        guard error == nil else { return }

                        var path: String?
                        if let url = item as? URL {
                            path = self?.saveToSharedContainer(url: url)
                        } else if let image = item as? UIImage,
                                  let data = image.jpegData(compressionQuality: 0.9) {
                            path = self?.saveDataToSharedContainer(data: data, ext: "jpg")
                        }

                        if let path = path {
                            sharedItems.append(["type": "image", "path": path])
                        }
                    }
                } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { item, error in
                        defer { group.leave() }
                        guard error == nil, let url = item as? URL else { return }
                        sharedItems.append(["type": "url", "value": url.absoluteString])
                    }
                } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { item, error in
                        defer { group.leave() }
                        guard error == nil, let text = item as? String else { return }
                        sharedItems.append(["type": "text", "value": text])
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            if !sharedItems.isEmpty {
                let userDefaults = UserDefaults(suiteName: self.appGroupId)
                if let data = try? JSONSerialization.data(withJSONObject: sharedItems) {
                    userDefaults?.set(data, forKey: "SharedItems")
                    userDefaults?.synchronize()
                }
            }

            self.openHostApp()
        }
    }

    private func saveToSharedContainer(url: URL) -> String? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId
        ) else { return nil }

        let fileName = "\(UUID().uuidString).\(url.pathExtension.isEmpty ? "jpg" : url.pathExtension)"
        let destURL = containerURL.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: url, to: destURL)
            return destURL.path
        } catch {
            return nil
        }
    }

    private func saveDataToSharedContainer(data: Data, ext: String) -> String? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId
        ) else { return nil }

        let fileName = "\(UUID().uuidString).\(ext)"
        let destURL = containerURL.appendingPathComponent(fileName)

        do {
            try data.write(to: destURL)
            return destURL.path
        } catch {
            return nil
        }
    }

    private func openHostApp() {
        guard let url = URL(string: "ceptesef://share") else {
            close()
            return
        }

        // Runtime'da UIApplication.shared'e erişerek URL aç.
        // Responder chain yaklaşımı yeni iOS sürümlerinde güvenilir değil.
        let className = "UIApplication"
        if let appClass = NSClassFromString(className) as? NSObject.Type {
            let sharedSel = NSSelectorFromString("sharedApplication")
            if appClass.responds(to: sharedSel),
               let appObj = appClass.perform(sharedSel)?.takeUnretainedValue() as? NSObject {
                let openSel = NSSelectorFromString("openURL:")
                if appObj.responds(to: openSel) {
                    appObj.perform(openSel, with: url)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.close()
                    }
                    return
                }
            }
        }

        // Fallback: Responder chain
        var responder: UIResponder? = self as UIResponder
        let selector = sel_registerName("openURL:")
        while responder != nil {
            if responder!.responds(to: selector) {
                responder!.perform(selector, with: url)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.close()
                }
                return
            }
            responder = responder?.next
        }

        close()
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
import AppKit
import SystemExtensions
import Combine

final class ExtensionManager: NSObject, ObservableObject, OSSystemExtensionRequestDelegate {
    @Published var status = "Enable once, then choose Nocturne Camera in Teams."
    @Published var pending = false

    func activate() {
        guard Bundle.main.bundleURL.path.hasPrefix("/Applications/") else {
            status = "Move Nocturne.app into Applications, reopen it, then enable the camera."; return
        }
        guard !pending else { return }
        pending = true
        status = "Requesting camera extension…"
        let request = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: VideoFormat.extensionID, queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    func deactivate() {
        guard !pending else { return }
        pending = true
        status = "Removing camera extension…"
        let request = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: VideoFormat.extensionID, queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        status = "Allow Nocturne under System Settings → General → Login Items & Extensions → Camera Extensions."
    }
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction { .replace }
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        pending = false
        status = result == .willCompleteAfterReboot ? "Restart your Mac to finish the camera extension change." : "Camera extension updated. Reopen Teams to refresh its camera list."
    }
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        pending = false
        let failure = error as NSError
        status = "Camera extension: \(failure.localizedDescription) (\(failure.domain), \(failure.code))."
    }
}

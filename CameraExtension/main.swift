import Foundation
import CoreMediaIO

let source = Provider()
CMIOExtensionProvider.startService(provider: source.provider)
CFRunLoopRun()

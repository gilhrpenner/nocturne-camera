import Foundation
import CoreMediaIO

func address(_ selector: Int) -> CMIOObjectPropertyAddress {
    CMIOObjectPropertyAddress(mSelector: UInt32(selector), mScope: UInt32(kCMIOObjectPropertyScopeGlobal), mElement: UInt32(kCMIOObjectPropertyElementMain))
}
func objects(_ object: CMIOObjectID, _ selector: Int) -> [CMIOObjectID] {
    var a = address(selector), size: UInt32 = 0
    guard CMIOObjectGetPropertyDataSize(object, &a, 0, nil, &size) == noErr else { return [] }
    var values = [CMIOObjectID](repeating: 0, count: Int(size) / 4)
    guard CMIOObjectGetPropertyData(object, &a, 0, nil, size, &size, &values) == noErr else { return [] }
    return values
}
func name(_ object: CMIOObjectID) -> String {
    var a = address(kCMIOObjectPropertyName), size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    var value: Unmanaged<CFString>?
    guard CMIOObjectGetPropertyData(object, &a, 0, nil, size, &size, &value) == noErr else { return "?" }
    return value?.takeUnretainedValue() as String? ?? "?"
}
var a = address(kCMIOHardwarePropertyAllowScreenCaptureDevices), allow: UInt32 = 1
CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &a, 0, nil, 4, &allow)
var found = false
for device in objects(CMIOObjectID(kCMIOObjectSystemObject), kCMIOHardwarePropertyDevices) where name(device) == "Nocturne Camera" {
    found = true
    print("CAMERA",device,name(device))
    for stream in objects(device, kCMIODevicePropertyStreams) {
        var a = address(kCMIOStreamPropertyDirection), direction: UInt32 = 99, size: UInt32 = 4
        CMIOObjectGetPropertyData(stream, &a, 0, nil, size, &size, &direction)
        print("STREAM",stream,name(stream),"direction",direction)
    }
}
if !found { print("FAIL: Nocturne Camera is absent from CoreMediaIO"); exit(1) }

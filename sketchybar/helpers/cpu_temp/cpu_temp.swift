import Foundation
import IOKit

@_silgen_name("IOHIDEventSystemClientCreate")
func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> OpaquePointer?

@_silgen_name("IOHIDEventSystemClientSetMatching")
func IOHIDEventSystemClientSetMatching(_ client: OpaquePointer, _ matching: CFDictionary)

@_silgen_name("IOHIDEventSystemClientCopyServices")
func IOHIDEventSystemClientCopyServices(_ client: OpaquePointer) -> CFArray?

@_silgen_name("IOHIDServiceClientCopyEvent")
func IOHIDServiceClientCopyEvent(_ service: OpaquePointer, _ type: Int64, _ options: Int32, _ flags: Int64) -> CFTypeRef?

@_silgen_name("IOHIDEventGetFloatValue")
func IOHIDEventGetFloatValue(_ event: CFTypeRef, _ field: UInt32) -> Double

let kIOHIDEventTypeTemperature: Int64 = 15

let matching: [String: Int] = [
    "PrimaryUsagePage": 0xff00,
    "PrimaryUsage": 0x0005,
]

guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else {
    print("--")
    exit(0)
}

IOHIDEventSystemClientSetMatching(client, matching as CFDictionary)

guard let services = IOHIDEventSystemClientCopyServices(client) else {
    print("--")
    exit(0)
}

let count = CFArrayGetCount(services)
var hottest = 0.0
var found = false

for i in 0..<count {
    guard let raw = CFArrayGetValueAtIndex(services, i) else { continue }
    let service = OpaquePointer(raw)
    guard let event = IOHIDServiceClientCopyEvent(service, kIOHIDEventTypeTemperature, 0, 0) else { continue }
    let field = UInt32(kIOHIDEventTypeTemperature << 16)
    let value = IOHIDEventGetFloatValue(event, field)
    // Drop obvious garbage (battery temp lives in this same set and rarely matches CPU)
    if value > 10 && value < 150 {
        if !found || value > hottest {
            hottest = value
            found = true
        }
    }
}

if found {
    print(Int(hottest.rounded()))
} else {
    print("--")
}

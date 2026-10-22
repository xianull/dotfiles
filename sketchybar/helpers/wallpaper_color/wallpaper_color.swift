// 主屏壁纸「顶部一条」的平均色，给 sketchybar 的 Wallpaper 配色用。
//   wallpaper_color [栏高]   输出 `0xffRRGGBB 路径|修改时间`，栏高默认 40pt
//   wallpaper_color --key   只输出 `路径|修改时间`，不解码图片（便宜，用来判断壁纸换没换）
// 按「填充屏幕」算出屏幕上真正看得见的那块图，再取它最上面栏高那么高的一条。
// ponytail: 只处理静态图片 + 填充缩放；动态 / 航拍壁纸、「适应屏幕」留白取不到，取色失败时退回 Gruvbox Material
import AppKit
import CoreImage

guard let screen = NSScreen.screens.first,  // 主屏（菜单栏所在那块）
      let url = NSWorkspace.shared.desktopImageURL(for: screen) else { exit(1) }

let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
let mtime = Int((attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)
let key = "\(url.path)|\(mtime)"
if CommandLine.arguments.contains("--key") { print(key); exit(0) }

let barHeight = CommandLine.arguments.dropFirst().compactMap { Double($0) }.first ?? 40
guard let image = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { exit(1) }
let img = image.extent, scr = screen.frame.size
let scale = max(scr.width / img.width, scr.height / img.height)  // 填充：盖满屏幕，多的部分居中裁掉
let visW = scr.width / scale, visH = scr.height / scale
let stripH = visH * barHeight / scr.height
// CoreImage 原点在左下角，看得见的那块的顶边 = 中心 + 一半高度
let strip = CGRect(x: img.midX - visW / 2, y: img.midY + visH / 2 - stripH, width: visW, height: stripH)

guard let avg = CIFilter(name: "CIAreaAverage",
                         parameters: [kCIInputImageKey: image, kCIInputExtentKey: CIVector(cgRect: strip)])?.outputImage
else { exit(1) }
var px = [UInt8](repeating: 0, count: 4)
// 不做色彩管理：在图片自己的（sRGB）数值上取平均，和屏幕上看到的颜色对得上
CIContext(options: [.workingColorSpace: NSNull()])
  .render(avg, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
print(String(format: "0xff%02x%02x%02x", px[0], px[1], px[2]) + " " + key)

import AppKit

func dataToNSImage(pngData: Data) -> NSImage? {
    guard let image = NSImage(data: pngData),
          image.size.width > 0, image.size.height > 0 else { return nil }
    return image
}

import AppKit

func decodeBase64ToImage(base64Image: String) -> NSImage? {
    // Android's Base64.DEFAULT can insert line breaks. Preserve PNG alpha.
    let normalized = base64Image.components(separatedBy: .whitespacesAndNewlines).joined()
    guard let data = Data(base64Encoded: normalized), let image = NSImage(data: data),
          image.size.width > 0, image.size.height > 0 else { return nil }
    return image
}

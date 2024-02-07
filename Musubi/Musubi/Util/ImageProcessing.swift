// ImageProcessing.swift

import Foundation
import UIKit

extension UIColor {
    // TODO: mute near-white colors but keep brightness of darker colors (e.g. La La Land cover)
    func musubi_Muted() -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        self.getHue(
            &hue,
            saturation: &saturation,
            brightness: &brightness,
            alpha: &alpha
        )
        return UIColor(
            hue: hue,
            saturation: saturation,
            brightness: brightness * 0.618,
            alpha: alpha
        )
    }
}

extension UIImage {
    func musubi_DominantColor() -> UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(
            x: inputImage.extent.origin.x,
            y: inputImage.extent.origin.y,
            z: inputImage.extent.size.width,
            w: inputImage.extent.size.height
        )

        // TODO: try histogram
        // https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference
        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]
        ) else {
            return nil
        }
        guard let outputImage = filter.outputImage else {
            return nil
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull])
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        return UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: CGFloat(bitmap[3]) / 255
        )
    }
    
    func musubi_CenterColor() -> UIColor? {
        guard let cgImage = cgImage,
            let pixelData = cgImage.dataProvider?.data
            else { return nil }
        
        let centerPoint = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        let pixelInfo = Int(centerPoint.y) * cgImage.bytesPerRow + Int(centerPoint.x) * 4;

        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        let r = CGFloat(data[pixelInfo]) / CGFloat(255.0)
        let g = CGFloat(data[pixelInfo+1]) / CGFloat(255.0)
        let b = CGFloat(data[pixelInfo+2]) / CGFloat(255.0)
        let a = CGFloat(data[pixelInfo+3]) / CGFloat(255.0)

        return UIColor(red: r, green: g, blue: b, alpha: a)

        /*
        let alphaInfo = cgImage.alphaInfo
        assert(alphaInfo == .premultipliedFirst || alphaInfo == .first || alphaInfo == .noneSkipFirst, "This routine expects alpha to be first component")

        let byteOrderInfo = cgImage.byteOrderInfo
        assert(byteOrderInfo == .order32Little || byteOrderInfo == .orderDefault, "This routine expects little-endian 32bit format")

        let a: CGFloat = CGFloat(data[pixelInfo+3]) / 255
        let r: CGFloat = CGFloat(data[pixelInfo+2]) / 255
        let g: CGFloat = CGFloat(data[pixelInfo+1]) / 255
        let b: CGFloat = CGFloat(data[pixelInfo  ]) / 255

        return UIColor(red: r, green: g, blue: b, alpha: a)
         */
    }
}

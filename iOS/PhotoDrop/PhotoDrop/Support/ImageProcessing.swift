//
//  ImageProcessing.swift
//  PhotoDrop
//
//  Created by Joshua Au on 11/7/26.
//

import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import os

func extractForeground(from image: Photo) async -> CGImage? {
    guard let ciImage = CIImage(data: image.data, options: [.applyOrientationProperty: true]),
          let ciMask = createMask(from: ciImage),
          let filter = CIFilter(name: "CIBlendWithMask") else {
        return nil
    }
    
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    filter.setValue(ciMask, forKey: kCIInputMaskImageKey)

    guard let outputCI = filter.outputImage else { return nil }
    let context = CIContext()
    let finalCG = context.createCGImage(outputCI, from: outputCI.extent)
    
    return finalCG
}

private func createMask(from inputImage: CIImage) -> CIImage? {
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(ciImage: inputImage)
    
    do {
        try handler.perform([request])
        
        // TODO: just get the mask for the object in the center?
        if let result = request.results?.first {
            let mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
            return CIImage(cvPixelBuffer: mask)
        }
    } catch {
        logger.log("Error creating mask: \(error)")
    }
    
    return nil
}

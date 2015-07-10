import Foundation
import UIKit

private let DefaultCalculateNumberColors = 16

private let CalculateBitmapMinDimension: CGFloat = 100
extension UIImage {
    func getPixelDataScaled(scale: CGFloat, pixelSkip:Int = 10) -> [Color] {
        // convert the source to RGB8888 to ensure we can interpolate it
        let source = self.CGImage
        var imageWidth = CGImageGetWidth(source)
        var imageHeight = CGImageGetHeight(source)
        // scale the image size based on the quality
        imageWidth = Int(CGFloat(imageWidth) * scale);
        imageHeight = Int(CGFloat(imageHeight) * scale);
        // create a colorspace in RGB
        let colorSpace = CGColorSpaceCreateDeviceRGB();
        // create a holder for the bitmap data
        let dataLength = Int(imageWidth * imageHeight) * 4;
        let bitmapData = UnsafeMutablePointer<UInt8>.alloc(1)
        bitmapData[0] = 0
        // base constants for the image data
        let bytesPerPixel = 4;
        let bytesPerRow = bytesPerPixel * Int(imageWidth);
        let bitsPerComponent = 8;
        // create the image context
        let context = CGBitmapContextCreate(bitmapData, imageWidth, imageHeight, bitsPerComponent, bytesPerPixel, colorSpace, CGBitmapInfo.ByteOrder32Big)
        // set the interpolation quality for reduction
        CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
        // draw the image
        CGContextDrawImage(context, CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight), source);
        
        let pixelCount = dataLength / 4;
        let pixelArrayTotal = Int(Double(pixelCount) * (1.0 / Double(pixelSkip)))
        
        var pixels = [Color]()
        for var index = 0; index < pixelCount; index += pixelSkip {
            let offset = index * 4
            let red = bitmapData[offset + 0]
            let green = bitmapData[offset + 1]
            let blue = bitmapData[offset + 2]
            let alpha = bitmapData[offset + 3]
            if (alpha > 124) {
                let color = Color.fromRGBA(red, green: green, blue: blue, alpha: alpha)
                pixels.append(color)
            }
        }
        
        return pixels
    }
    
    func getPixelData(atX x: Int, andY y: Int, count: Int) -> [Color] {
        var result = [Color]()

        let width = Int(size.width)
        let height = Int(size.height)

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width

        var pixelData = CGDataProviderCopyData(CGImageGetDataProvider(CGImage))
        var rawData = CFDataGetBytePtr(pixelData)

        // Now your rawData contains the image data in the RGBA8888 pixel format.
        var byteIndex = (bytesPerRow * y) + x * bytesPerPixel
        for i in 0..<count {
            let red   = rawData[byteIndex]
            let green = rawData[byteIndex + 1]
            let blue  = rawData[byteIndex + 2]
            let alpha = rawData[byteIndex + 3]
            byteIndex += bytesPerPixel

            var c = Color.fromRGBA(red, green: green, blue: blue, alpha: alpha)
//            if i < 10 {
//                var s = String(format: "%#08x: %#02x, %#02x, %#02x, %#02x", c, red, green, blue, alpha)
//                 println(s)
//            }
            result.append(c)
        }

        return result
    }

    /**
     * Scale the bitmap down so that it's smallest dimension is
     * {@value #CALCULATE_BITMAP_MIN_DIMENSION}px. If {@code bitmap} is smaller than this, than it
     * is returned.
     */
    func scaleToMaxSize(maxSize: CGFloat = CalculateBitmapMinDimension) -> UIImage {
        let minDimension = min(size.width, size.height)

        if (minDimension <= maxSize) {
            return self
        }

        let scaleRatio = minDimension / maxSize
        // return UIImage(CGImage: CGImage, scale: scaleRatio, orientation: UIImageOrientation.Up)!

        var newRect = CGRectIntegral(CGRectMake(0, 0, size.width / scaleRatio, size.height / scaleRatio));
        var transposedRect = CGRectMake(0, 0, newRect.size.width, newRect.size.height);
        var imageRef = self.CGImage;

        // Build a context that's the same dimensions as the new size
        // let context = CGBitmapContextCreate(nil, UInt(rect.size.width), UInt(rect.size.height), 8, 0, colorSpace, bitmapInfo)
        var bitmap = CGBitmapContextCreate(nil, Int(newRect.size.width), Int(newRect.size.height), CGImageGetBitsPerComponent(imageRef), 0, CGImageGetColorSpace(imageRef), CGImageGetBitmapInfo(imageRef))

        // Rotate and/or flip the image if required by its orientation
        CGContextConcatCTM(bitmap, CGAffineTransformIdentity);

        // Set the quality level to use when rescaling
        CGContextSetInterpolationQuality(bitmap, kCGInterpolationHigh);

        // Draw into the context; this scales the image
        CGContextDrawImage(bitmap, transposedRect, imageRef);

        // Get the resized image from the context and a UIImage
        var newImageRef = CGBitmapContextCreateImage(bitmap);
        var newImage = UIImage(CGImage: newImageRef)

        // Clean up
        // CGContextRelease(bitmap);
        // CGImageRelease(newImageRef);

        return newImage!;
    }

    class func fromColors(colors: ArraySlice<Color>) -> UIImage {
        let w: CGFloat = 1
        let h: CGFloat = 1
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(w * CGFloat(colors.count), h), true, 0.0)
        var ctx = UIGraphicsGetCurrentContext()
        CGContextSaveGState(ctx)

        for (i, color) in enumerate(colors) {
            var rect = CGRectMake(CGFloat(i) * w, 0, w, h)
            CGContextSetFillColorWithColor(ctx, color.toUIColor().CGColor)
            CGContextFillRect(ctx, rect)
        }

        CGContextRestoreGState(ctx)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
}

@objc public class PaletteObjc: NSObject {
    public let palette: Palette
    
    public convenience init(fromByteArray byteArray: UnsafePointer<UInt8>, byteArrayLen: Int, numColors: Int = DefaultCalculateNumberColors) {
        let palette = Palette(fromByteArray: byteArray, byteArrayLen: byteArrayLen, numColors: numColors)
        self.init(palette: palette)
    }
    
    init(palette: Palette) {
        self.palette = palette
        super.init()
    }
}

@objc public class Palette: Printable {
    public var description: String {
        return "Palette"
    }
    
    private static let TargetDarkLuma: CGFloat = 0.26
    private static let MaxDarkLuma: CGFloat = 0.45

    private static let MinLightLuma: CGFloat = 0.55
    private static let TargetLightLuma: CGFloat = 0.74

    private static let MinNormalLuma: CGFloat = 0.3
    private static let TargetNormalLuma: CGFloat = 0.5
    private static let MaxNormalLuma: CGFloat = 0.7

    private static let TargetMutedSaturation: CGFloat = 0.3
    private static let MaxMutedSaturation: CGFloat = 0.4

    private static let TargetVibrantSaturation: CGFloat = 1.0
    private static let MinVibrantSaturation: CGFloat = 0.35

    private static let WeightSaturation: CGFloat = 3
    private static let WeightLuma: CGFloat = 6
    private static let WeightPopulation: CGFloat = 1
    
    public var swatches: [Swatch]
    private var highestPopulation: Int = 0
    
    public var vibrantSwatch: Swatch?
    public var mutedSwatch: Swatch?

    public var darkVibrantSwatch: Swatch?
    public var darkMutedSwatch: Swatch?

    public var lightVibrantSwatch: Swatch?
    public var lightMutedColor: Swatch?

    public class GenerateOperation: NSOperation {
        private var image: UIImage
        public var palette: Palette? = nil

        init(image: UIImage) {
            self.image = image
        }

        override public func main() {
            palette = Palette(fromImage: image)
        }
    }

    /**
    * Generate a {@link Palette} from a {@link Bitmap} using the specified {@code numColors}.
    * Good values for {@code numColors} depend on the source image type.
    * For landscapes, a good values are in the range 12-16. For images which are largely made up
    * of people's faces then this value should be increased to 24-32.
    *
    * @param numColors The maximum number of colors in the generated palette. Increasing this
    *                  number will increase the time needed to compute the values.
    */
    public convenience init(fromImage image: UIImage, numColors: Int = DefaultCalculateNumberColors) {
        let scaledImage = image.scaleToMaxSize()
        let quantizer = ColorCutQuantizer(fromImage: scaledImage, maxColors: numColors)
        self.init(swatches: quantizer.getQuantizedColors())
    }
    
    public convenience init(fromImage image: UIImage, scale: CGFloat, pixelSkip: Int = 10, numColors: Int = DefaultCalculateNumberColors) {
        let pixels = image.getPixelDataScaled(scale, pixelSkip: pixelSkip)
        println("\nAnalyzing \(pixels.count) pixels")
        var time = CACurrentMediaTime()
        let histogram = ColorHistogram(pixels: pixels)
        println("histogram: \(CACurrentMediaTime() - time)")
        time = CACurrentMediaTime()
        let quantizer = ColorCutQuantizer(colorHistogram: histogram, maxColors: numColors)
        println("quantizer: \(CACurrentMediaTime() - time)")
        self.init(swatches: quantizer.getQuantizedColors())
    }
    
    public convenience init(fromByteArray byteArray: UnsafePointer<UInt8>, byteArrayLen: Int, numColors: Int = DefaultCalculateNumberColors) {
        var pixels = [Color]()
        for var index = 0; index < byteArrayLen; ++index {
            let red = byteArray[index++]
            let green = byteArray[index++]
            let blue = byteArray[index++]
            let alpha = byteArray[index++]
            let c = Color.fromRGBA(red, green: green, blue: blue, alpha: alpha)
            pixels.append(c)
        }
        let histogram = ColorHistogram(pixels: pixels)
        let quantizer = ColorCutQuantizer(colorHistogram: histogram, maxColors: numColors)
        self.init(swatches: quantizer.getQuantizedColors())
    }

    private init(swatches: [Swatch]) {
        self.swatches = swatches
        highestPopulation = findMaxPopulation()

        vibrantSwatch = findColor(Palette.TargetNormalLuma,
            minLuma: Palette.MinNormalLuma,
            maxLuma: Palette.MaxNormalLuma,
            targetSaturation: Palette.TargetVibrantSaturation,
            minSaturation: Palette.MinVibrantSaturation,
            maxSaturation: 1.0)
        lightVibrantSwatch = findColor(Palette.TargetLightLuma,
            minLuma: Palette.MinLightLuma,
            maxLuma: 1.0,
            targetSaturation: Palette.TargetVibrantSaturation,
            minSaturation: Palette.MinVibrantSaturation,
            maxSaturation: 1.0)
        darkVibrantSwatch = findColor(Palette.TargetDarkLuma, minLuma: 0.0, maxLuma: Palette.MaxDarkLuma, targetSaturation: Palette.TargetVibrantSaturation, minSaturation: Palette.MinVibrantSaturation, maxSaturation: 1.0)

        mutedSwatch = findColor(Palette.TargetNormalLuma, minLuma: Palette.MinNormalLuma, maxLuma: Palette.MaxNormalLuma, targetSaturation: Palette.TargetMutedSaturation, minSaturation: 0.0, maxSaturation: Palette.MaxMutedSaturation)
        lightMutedColor = findColor(Palette.TargetLightLuma, minLuma: Palette.MinLightLuma, maxLuma: 1.0, targetSaturation: Palette.TargetMutedSaturation, minSaturation: 0.0, maxSaturation: Palette.MaxMutedSaturation)
        darkMutedSwatch = findColor(Palette.TargetDarkLuma, minLuma: 0.0, maxLuma: Palette.MaxDarkLuma, targetSaturation: Palette.TargetMutedSaturation, minSaturation: 0.0, maxSaturation: Palette.MaxMutedSaturation)

        // Now try and generate any missing colors
        generateEmptySwatches()
    }

    /**
    * Generate a {@link Palette} asynchronously. {@link PaletteAsyncListener#onGenerated(Palette)}
    * will be called with the created instance. The resulting {@link Palette} is the same as what
    * would be created by calling {@link #generate(Bitmap, int)}.
    *
    * @param listener Listener to be invoked when the {@link Palette} has been generated.
    *
    * @return the {@link android.os.AsyncTask} used to asynchronously generate the instance.
    */
    public class func generateAsync(image: UIImage, numColors: Int = DefaultCalculateNumberColors) -> NSOperation {
        return GenerateOperation(image: image)
    }

    /**
    * @return true if we have already selected {@code swatch}
    */
    private func isAlreadySelected(swatch: Swatch?) -> Bool {
        return vibrantSwatch == swatch ||
            darkVibrantSwatch == swatch ||
            lightVibrantSwatch == swatch ||
            mutedSwatch == swatch ||
            darkMutedSwatch == swatch ||
            lightMutedColor == swatch;
    }

    private func findColor(targetLuma: CGFloat, minLuma: CGFloat, maxLuma: CGFloat, targetSaturation: CGFloat, minSaturation: CGFloat, maxSaturation: CGFloat) -> Swatch? {
        var max: Swatch? = nil
        var maxValue: CGFloat = 0.0

        for swatch in swatches {
            var sat = swatch.hsl[1]
            var luma = swatch.hsl[2]

            if (sat >= minSaturation &&
                sat <= maxSaturation &&
                luma >= minLuma &&
                luma <= maxLuma &&
                !isAlreadySelected(swatch)) {
                    var thisValue = Palette.createComparisonValue(sat, targetSaturation: targetSaturation, luma: luma, targetLuma: targetLuma, population: swatch.population, highestPopulation: highestPopulation)
                    if (max == nil || thisValue > maxValue) {
                        max = swatch
                        maxValue = thisValue
                    }
            }
        }

        return max
    }

    /**
    * Try and generate any missing swatches from the swatches we did find.
    */
    private func generateEmptySwatches() {
        if (vibrantSwatch == nil) {
            // If we do not have a vibrant color...
            if (darkVibrantSwatch != nil) {
                // ...but we do have a dark vibrant, generate the value by modifying the luma
                var newHsl = Palette.copyHslValues(darkVibrantSwatch!)
                newHsl[2] = Palette.TargetNormalLuma
                vibrantSwatch = Swatch(rgb: ColorUtils.HSLtoRGB(newHsl), population: 0)
            }
        }

        if (darkVibrantSwatch == nil) {
            // If we do not have a dark vibrant color...
            if (vibrantSwatch != nil) {
                // ...but we do have a vibrant, generate the value by modifying the luma
                var newHsl = Palette.copyHslValues(vibrantSwatch!)
                newHsl[2] = Palette.TargetDarkLuma
                darkVibrantSwatch = Swatch(rgb: ColorUtils.HSLtoRGB(newHsl), population: 0)
            }
        }
    }

    /**
    * Find the {@link Swatch} with the highest population value and return the population.
    */
    private func findMaxPopulation() -> Int {
        var population = 0;
        for swatch in swatches {
            population = max(population, swatch.population)
        }
        return population;
    }

    private class func createComparisonValue(saturation: CGFloat, targetSaturation: CGFloat, luma: CGFloat, targetLuma: CGFloat, population: Int, highestPopulation: Int) -> CGFloat {
        return Palette.weightedMean(
            (invertDiff(saturation, targetValue: targetSaturation), WeightSaturation),
            (invertDiff(luma, targetValue: targetLuma), WeightLuma),
            (CGFloat(population / highestPopulation), WeightPopulation))
    }

    /**
    * Copy a {@link Swatch}'s HSL values into a new float[].
    */
    private class func copyHslValues(color: Swatch) -> [CGFloat] {
        return [CGFloat](arrayLiteral: color.hsl[0], color.hsl[1], color.hsl[2])
    }

    /**
    * Returns a value in the range 0-1. 1 is returned when {@code value} equals the
    * {@code targetValue} and then decreases as the absolute difference between {@code value} and
    * {@code targetValue} increases.
    *
    * @param value the item's value
    * @param targetValue the value which we desire
    */
    private class func invertDiff(value: CGFloat, targetValue: CGFloat) -> CGFloat {
        return 1.0 - abs(value - targetValue);
    }
    
    private class func weightedMean(values: (val: CGFloat, weight: CGFloat)...) -> CGFloat {
        var sum: CGFloat = 0.0
        var sumWeight: CGFloat = 0.0
        
        for value in values {
            sum += (value.val * value.weight)
            sumWeight += value.weight
        }
        
        return CGFloat(sum / sumWeight)
    }
}

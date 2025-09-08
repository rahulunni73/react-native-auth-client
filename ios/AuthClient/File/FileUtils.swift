///FileUtils.swift
///AuthClient-iOS
///Created by Rahul Narayanan Unni on 28/07/24..
///Lead Software Engineer @Ospyn Technologies Limited



import Foundation
import PDFKit


struct FileUtils {
  
  
  // Helper method to save image to documents directory and return the file path
  static func saveImage(image: UIImage, withName name: String) -> String? {
    guard let data = image.jpegData(compressionQuality: 1.0) else {
      return nil
    }
    
    let fileManager = FileManager.default
    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    let fileName = generateFileName(withMimeType: "image/jpeg");
    let fileURL = documentsURL.appendingPathComponent("\(fileName)")
    
    do {
      try data.write(to: fileURL)
      return fileURL.path
    } catch {
      print("Error saving image: \(error)")
      return nil
    }
  }
  
  
  
  
  
  // Helper method to save the PDF document to the documents directory and return the file path
  static func savePDF(document: PDFDocument, withName name: String) -> String? {
    let fileManager = FileManager.default
    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    let fileName = generateFileName(withMimeType: "application/pdf");
    let fileURL = documentsURL.appendingPathComponent("\(fileName)")
    
    if document.write(to: fileURL) {
      return fileURL.path
    } else {
      print("Failed to save PDF document.")
      return nil
    }
  }
  
  
  
  
  
  
  static func  resizeImage(image: UIImage, targetSize: CGSize) -> UIImage? {
    let size = image.size
    let widthRatio  = targetSize.width  / size.width
    let heightRatio = targetSize.height / size.height
    var newSize: CGSize
    
    if(widthRatio > heightRatio) {
      newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
    } else {
      newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
    }
    
    // Calculate the centerX and centerY
    let centerX = (targetSize.width - newSize.width) / 2.0
    let centerY = (targetSize.height - newSize.height) / 2.0
    
    // The rect of the image should be based on the center calculations
    let rect = CGRect(x: centerX,
                      y: centerY,
                      width: newSize.width,
                      height: newSize.height)
    
    // The graphics context should be created with the page dimensions
    UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
    
    // The rest remains the same
    image.draw(in: rect)
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return newImage
  }
  
  
  
  
  static func generateFileName(withMimeType mimeType: String) -> String {
    // Get the current timestamp
    let timestamp = Int(Date().timeIntervalSince1970)
    
    // Extract file extension from the MIME type
    var fileExtension = ""
    if let ext = mimeType.split(separator: "/").last {
      fileExtension = String(ext)
    }
    
    // Generate the file name with timestamp and extension
    let fileName = "\(getTimeStamp()).\(fileExtension)"
    return fileName
  }
  
  
  
  
  // Static function to generate a timestamp in the same format as the JavaScript example
  static func getTimeStamp() -> String {
      let date = Date()
      let calendar = Calendar.current

      let year = calendar.component(.year, from: date)
      let month = calendar.component(.month, from: date)
      let day = calendar.component(.day, from: date)
      let hour = calendar.component(.hour, from: date)
      let minute = calendar.component(.minute, from: date)
      let millisecond = Int((date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)) * 1000)

      return "\(year)\(String(format: "%02d", month))\(String(format: "%02d", day))_\(String(format: "%02d", hour))\(String(format: "%02d", minute))\(String(format: "%03d", millisecond))"
  }
  
  
  
  static func getFileContentLength(for fileURL: URL) -> Int64? {
      do {
          let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
          if let fileSize = attributes[.size] as? Int64 {
              return fileSize
          }
      } catch {
          print("Error retrieving file size: \(error.localizedDescription)")
      }
      return nil
  }
  
  
}


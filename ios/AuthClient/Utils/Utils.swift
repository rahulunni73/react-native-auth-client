///ApiAuthResponse.swift
///AuthClient-iOS
///Created by Rahul Narayanan Unni on 28/07/24..
///Lead Software Engineer @Ospyn Technologies Limited



import Foundation


struct Utils {
  
  static func createURL(endpoint:String) -> String {
    return Client.baseURL + endpoint;
  }
  
  
  static func convertJsObjectToDictionary(_ jsObject: Any) -> [String: Any]? {
      
    guard let jsObject = jsObject as? [String: Any] else {
          print("Invalid JavaScript object")
          return nil
      }
      
      var dictionary = [String: Any]()
      
      for (key, value) in jsObject {
        
          if let nestedObject = value as? [String: Any] {
              dictionary[key] = convertJsObjectToDictionary(nestedObject)
          }
        
        if let array = value as? [Any] {
          print("Key '\(key)' contains an array: \(array)")
          dictionary[key] = array;
        }
        
        else {
              dictionary[key] = value
          }
      }
      
      return dictionary
  }
  
  
  
  static func toJsonDataFromDictionary(dictionary result:[String:Any]) -> String {
    do {
      let jsonData = try JSONSerialization.data(withJSONObject: result, options: [])
      if let jsonString = String(data: jsonData, encoding: .utf8) {
        return jsonString;
        //self.delegate.onResponseHandler(result: jsonString);
      } else {
        let _ = NSError(domain: "com.myapp.error", code: 102, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON string"]);
        
        return "Failed to encode JSON string";
        //self.delegate.onResponseHandler(result: "Failed to encode JSON string");
      }
    } catch { print(error);
      return "Failed to encode JSON string";
    }
  }
  
  
  
  
  
  static func writeBase64StringToFile(base64String: String, fileName: String, filePath: String) -> Bool {
      // Determine the file extension based on the MIME type
//      let fileExtension: String
//      switch mimeType {
//      case "image/jpeg":
//          fileExtension = "jpg"
//      case "image/png":
//          fileExtension = "png"
//      case "application/pdf":
//          fileExtension = "pdf"
//      default:
//          print("Unsupported MIME type")
//          return false
//      }

      // Append the appropriate file extension to the file path
      let completeFilePath = "\(filePath)/\(fileName)"

      // Convert the Base64 string to Data
      guard let fileData = Data(base64Encoded: base64String) else {
          print("Error: Couldn't convert Base64 string to Data")
          return false
      }

      // Create a URL from the complete file path
      let fileURL = URL(fileURLWithPath: completeFilePath)

      do {
          // Write the Data to the file
          try fileData.write(to: fileURL)
          print("File written successfully to \(completeFilePath)")
          return true
      } catch {
          // Handle the error
          print("Error writing file: \(error.localizedDescription)")
          return false
      }
  }
  
  
  
  
  

}


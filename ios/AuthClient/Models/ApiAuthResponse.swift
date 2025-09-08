///ApiAuthResponse.swift
///AuthClient-iOS
///Created by Rahul Narayanan Unni on 28/07/24..
///Lead Software Engineer @Ospyn Technologies Limited



import Foundation


struct ApiAuthResponse:Codable {
  
  public let token:String?;
  public let refreshToken:String?;
  public let error:Bool?;
  public let tokenExpiry:String?;
  public let refreshTokenExpiry:String?;
  public let errorReason:Int?;
  public let errorMessage:String?;
  public let encryptedContent:String?;
  

  /*
  public func getToken() -> String{
      return token;
  }



  public func getRefreshToken() -> String {
      return refreshToken;
  }


  public func isError() -> Bool {
      return error;
  }



  public func getTokenExpiry() -> String {
      return tokenExpiry;
  }


  public func getRefreshTokenExpiry() -> String {
      return refreshTokenExpiry;
  }
  
  
  public func getErrorReason() -> Int {
      return errorReason;
  }

  

  public func getErrorMessage() -> String {
      return errorMessage
  }



  public func getEncryptedContent() -> String {
      return encryptedContent;
  }
  
  */
}


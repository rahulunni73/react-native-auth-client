///ApiClientResult.swift
///AuthClient-iOS
///Created by Rahul Narayanan Unni on 28/07/24..
///Lead Software Engineer @Ospyn Technologies Limited



import Foundation


struct ApiClientResult:Codable {
  //private JsonElement data;
  public let error:Bool?;
  public let errorMessage:String?;
  public let errorReason:Int?;
  public let encryptedContent:String?;
  public let success:Bool?;
  public let message:String?;
  public let errorCode:Int?;
  let data: ErrorData?

}


struct ErrorData: Codable {
    let isError: Bool
    let errorMessage: String
}


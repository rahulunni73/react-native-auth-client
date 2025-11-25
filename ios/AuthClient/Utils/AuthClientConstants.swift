///ApiAuthResponse.swift
///AuthClient-iOS
///Created by Rahul Narayanan Unni on 28/07/24..
///Lead Software Engineer @Ospyn Technologies Limited

import Foundation


struct AuthClientConstants {

  // Authentication status codes
  public static let AUTH_SUCCESS:Int = 0;

  public static let AUTH_FAILED:Int = 1;

  public static let TOKEN_EXPIRED:Int = 2;

  public static let INTERNAL_ERROR:Int = 3;

  public static let BAD_TOKEN:Int = 4;

  // Network constants
  public static let DOWNLOAD = "DOWNLOAD"

  public static let AUTH_LOGIN_URL = "authenticate"

  public static let BAD_TOKEN_TEXT = "Bad token"

}



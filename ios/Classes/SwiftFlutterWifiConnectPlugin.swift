import Flutter
import UIKit
import NetworkExtension
import SystemConfiguration.CaptiveNetwork
import os.log

public class SwiftFlutterWifiConnectPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_wifi_connect", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterWifiConnectPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch (call.method) {
        case "disconnect":
          result(disconnect())
          return

        case "getSSID":
          result(getSSID())
          return

        case "connect":
          let args = try GetArgs(arguments: call.arguments)
          let hotspotConfig = NEHotspotConfiguration.init(ssid: args["ssid"] as! String)
          hotspotConfig.joinOnce = !(args["saveNetwork"] as! Bool);
          connect(hotspotConfig: hotspotConfig, result: result)
          return

        case "prefixConnect":
          guard #available(iOS 13.0, *) else {
            result(FlutterError(code: "iOS must be above 13", message: "Prefix connect doesn't work on iOS pre 13", details: nil))
            return
          }
          let args = try GetArgs(arguments: call.arguments)
          let hotspotConfig = NEHotspotConfiguration.init(ssidPrefix: args["ssid"] as! String)
          hotspotConfig.joinOnce = !(args["saveNetwork"] as! Bool);
          connect(hotspotConfig: hotspotConfig, result: result)
          return

        case "secureConnect":
          let args = try GetArgs(arguments: call.arguments)
          let hotspotConfig = NEHotspotConfiguration.init(ssid: args["ssid"] as! String, passphrase: args["password"] as! String, isWEP: args["isWep"] as! Bool)
          hotspotConfig.joinOnce = !(args["saveNetwork"] as! Bool);
          connect(hotspotConfig: hotspotConfig, result: result)
          return

        case "securePrefixConnect":
          guard #available(iOS 13.0, *) else {
            result(FlutterError(code: "iOS must be above 13", message: "Prefix connect doesn't work on iOS pre 13", details: nil))
            return
          }
          let args = try GetArgs(arguments: call.arguments)
          let hotspotConfig = NEHotspotConfiguration.init(ssidPrefix: args["ssid"] as! String, passphrase: args["password"] as! String, isWEP: args["isWep"] as! Bool)
          hotspotConfig.joinOnce = !(args["saveNetwork"] as! Bool);
          connect(hotspotConfig: hotspotConfig, result: result)
          return

        default:
          result(FlutterMethodNotImplemented)
          return
      }
    } catch ArgsError.MissingArgs {
        result(
          FlutterError( code: "missingArgs", 
            message: "Missing args",
            details: "Missing args."))
        return
    } catch {
        result(
          FlutterError( code: "unknownError", 
            message: "Unkown iOS error",
            details: error))
        return
    }
  }

  enum ArgsError: Error {
    case MissingArgs
  }

  func GetArgs(arguments: Any?) throws -> [String : Any]{
    guard let args = arguments as? [String : Any] else {
      throw ArgsError.MissingArgs
    }
    return args
  }

  @available(iOS 11, *)
  private func connect(hotspotConfig: NEHotspotConfiguration, result: @escaping FlutterResult) -> Void {
    os_log("connecting to wifi", log: .default, type: .info)
    NEHotspotConfigurationManager.shared.apply(hotspotConfig) { [weak self] (error) in

      if let error = error as NSError? {
        // https://developer.apple.com/documentation/networkextension/nehotspotconfigurationerror
        switch(error.code) {
        case NEHotspotConfigurationError.alreadyAssociated.rawValue:
            os_log("ssid already associated, assuming connection successful", log: .default, type: .info)
            result(true)
            break
        case NEHotspotConfigurationError.userDenied.rawValue:
            os_log("user denied wifi connection", log: .default, type: .error)
            result(
              FlutterError( code: "userDenied", 
                message: "User denied WiFi connection",
                details: "User denied WiFi connection"))
            break
        default:
            os_log("error code: %u localizedMessage: '%@'", log: .default, type: .error, error.code, error.localizedDescription)
            result(
              FlutterError( code: "unknownError", 
              message: error.localizedDescription,
              details: error.localizedDescription))
            break
        }
        return
      }
      guard let this = self else {
        os_log("this is not self", log: .default, type: .error)
        result(
          FlutterError( code: "thisIsNotSelf", 
            message: "this is not self",
            details: "this is not self"))
        return
      }
      result(true)
      return
    }
  }

  @available(iOS 11, *)   
  private func disconnect() -> Bool {
    NEHotspotConfigurationManager.shared.getConfiguredSSIDs { (ssidsArray) in
      for ssid in ssidsArray {
        // disconnect from every network that was configured by the app
        os_log("disconnecting from: %@", log: .default, type: .error, ssid)
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
      }
    }
    return true
  }

  private func getSSID() -> String? {
    var ssid: String?
    if let interfaces = CNCopySupportedInterfaces() as NSArray? {
      for interface in interfaces {
        if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
          ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
          break
        }
      }
    }
    return ssid
  }
}

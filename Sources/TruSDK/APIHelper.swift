//
//  SessionEndpoint.swift
//  
//
//  Created by Murat Yakici on 02/06/2021.
//

#if canImport(UIKit)
import UIKit
#else
import Foundation
#endif

final class APIHelper {

    let DEVICE_IP_URL = "https://eu.api.tru.id/public/coverage/v0.1/device_ip"
    
    private let session: URLSession

    init() {
        session = APIHelper.createSession()
    }

    private static func createSession() -> URLSession {

        let configuration = URLSessionConfiguration.ephemeral //We do not want OS to cache or persist
        configuration.allowsCellularAccess = true
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = true        
        configuration.networkServiceType = .responsiveData

        return URLSession(configuration: configuration)
    }

    func makeRequest<U: Decodable>(urlRequest: URLRequest,
                                   onCompletion: @escaping (ConnectionResult<URL, U, ReachabilityError>) -> Void){

        let task = session.dataTask(with: urlRequest) { (data, response, error) in

            DispatchQueue.main.async {
                if let error = error {
                    onCompletion(.complete(ReachabilityError(type: "Network", title: "Error", status: -1, detail: error.localizedDescription)))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    onCompletion(.complete(ReachabilityError(type: "HTTP", title: "Error", status: -1, detail: "No response")))
                    return
                }

                guard let data = data else {
                    onCompletion(.complete(ReachabilityError(type: "HTTP", title: "Error", status: httpResponse.statusCode, detail: "No data")))
                    return
                }

                if (200...299).contains(httpResponse.statusCode),
                   let dataModel = try? JSONDecoder().decode(U.self, from: data) {
                    onCompletion(.data(dataModel))
                } else if (300...399).contains(httpResponse.statusCode){
                    let redirectURL = httpResponse.value(forHTTPHeaderField: "Location")
                    onCompletion(.follow(URL(string: redirectURL ?? "https://unknown-redirect-url")!))
                } else {
                    if let dataModel = try? JSONDecoder().decode(ReachabilityError.self, from: data) {
                        onCompletion(.complete(dataModel))
                    } else {
                        onCompletion(.complete(ReachabilityError(type: "HTTP", title: "Error", status: httpResponse.statusCode, detail: "Unexpected data form Server for failure")))
                    }
                }
            }

        }

        task.resume()
    }

    func createURLRequest(method: String, url: URL, payload:[String : String]?) -> URLRequest {

        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        urlRequest.httpMethod = method

        if let payload = payload {
            let jsonData = try! JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            urlRequest.httpBody = jsonData
        }

        return urlRequest
    }
}

public func userAgent(sdkVersion: String) -> String {
    return "tru-sdk-ios/\(sdkVersion) \(deviceString())"
}

public func deviceString() -> String {
    var device: String
    #if canImport(UIKit)
    device = UIDevice.current.systemName + "/" + UIDevice.current.systemVersion
    #elseif os(macOS)
    device = "macOS / Unknown"
    #endif
    return device
}

func deviceInfo() -> String {
    let manufacturer = "Apple" //Build.MANUFACTURER //The manufacturer of the product/hardware.
    var model =  "An Apple Device"//Build.MODEL ///** The end-user-visible name for the end product. */
    var osName = "Unknown" //Version
    var osVersion = ""//System version
    #if canImport(UIKit)
    osName = UIDevice.current.systemName //name of the operating system
    osVersion = UIDevice.current.systemVersion //current version of the operating system
    model = UIDevice.current.model //The model of the device.
    #endif

    return "DeviceInfo: \(manufacturer), \(model) ,\(osName), \(osVersion), \n User-Agent: \(userAgent(sdkVersion: TruSdkVersion))\n"
}

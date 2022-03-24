//
//  ReachabilityDetails.swift
//  
//
//  Created by Murat Yakici on 02/06/2021.
//

import Foundation

/// A struct to hold the details of the Cellular network a request is made.
@objc public class ReachabilityDetails: NSObject, Codable {
    public let countryCode: String
    public let networkId: String
    public let networkName: String
    public let products: [Product]?
    
    public init(countryCode: String, networkId: String, networkName: String, products: [Product]?) {
        self.countryCode = countryCode
        self.networkId = networkId
        self.networkName = networkName
        self.products = products
    
    }
    
    private enum CodingKeys : String, CodingKey {
        case countryCode = "country_code", networkId = "network_id", networkName = "network_name"
        case products
    }
    
    public static func == (lhs: ReachabilityDetails, rhs: ReachabilityDetails) -> Bool {
        return lhs.countryCode == rhs.countryCode &&
            lhs.networkId == rhs.networkId &&
            lhs.networkName == lhs.networkName &&
            lhs.products == rhs.products
    }
    
    public func toJsonString() -> String {
        var result = "{}"
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        do {
            let jsonData = try encoder.encode(self)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                result = jsonString
            }
        } catch {
            print(error.localizedDescription)
        }
        
        return result
    }
}

/// The TruID products available for the application developer on the celluar network the app is connected to.
@objc public class Product: NSObject, Codable {
    public let productId: String
    public let productName: String
    
    public init(productId: String, productName: String) {
        self.productId = productId
        self.productName = productName
    }
    
    private enum CodingKeys : String, CodingKey {
        case productId = "product_id", productName = "product_name"
    }
}


/// A struct to hold the details of the error when `isReachable(...) request is made.
/// If the request was not made on a Cellular network, this struct will represent the details of the error.
@objc public class ReachabilityError: NSObject, Error, Codable {
    public let type: String
    public let title: String
    public let status: Int
    public let detail: String
    
    public init(type: String, title: String, status: Int, detail: String) {
        self.type = type
        self.title = title
        self.status = status
        self.detail = detail
        
    }
    private enum CodingKeys : String, CodingKey {
        case type = "type", title = "title", status = "status", detail = "detail"
        
    }
    
    public func toJsonStringError() -> String {
        var result = "{}"
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        do {
            let jsonData = try encoder.encode(self)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                result = jsonString
            }
        } catch {
            print(error.localizedDescription)
        }
        return result
    }
}


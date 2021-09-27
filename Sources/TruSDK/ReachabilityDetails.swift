//
//  ReachabilityDetails.swift
//  
//
//  Created by Murat Yakici on 02/06/2021.
//

import Foundation

/// A struct to hold the details of the Cellular network a request is made.
public struct ReachabilityDetails: Codable, Equatable {
    public let countryCode: String
    public let networkId: String
    public let networkName: String
    public let products: [Product]?
    
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
public struct Product: Codable, Equatable {
    public let productId: String
    public let productName: String
    
    private enum CodingKeys : String, CodingKey {
        case productId = "product_id", productName = "product_name"
    }
}


/// A struct to hold the details of the error when `isReachable(...) request is made.
/// If the request was not made on a Cellular network, this struct will represent the details of the error.
public struct ReachabilityError: Error, Codable, Equatable {
    public let type: String
    public let title: String
    public let status: Int
    public let detail: String
    
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


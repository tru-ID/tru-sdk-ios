//
//  ReachabilityDetails.swift
//  
//
//  Created by Murat Yakici on 02/06/2021.
//

import Foundation
public struct ReachabilityDetails: Codable {
   let countryCode: String
   let networkId: String
   let networkName: String
   let products: [Product]?
   let link: String
}

public struct ReachabilityError: Error, Codable {
   let type: String
   let title: String
   let status: Int
   let detail: String
}

public struct Product: Codable {
    let productId: String
    let productType: ProductType
}

public enum ProductType:String, Codable {
    case PhoneCheck = "Phone Check"
    case SIMCheck = "Sim Check"
    case SubscriberCheck = "Subscriber Check"
}

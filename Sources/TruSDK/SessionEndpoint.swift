//
//  SessionEndpoint.swift
//  
//
//  Created by Murat Yakici on 02/06/2021.
//

import Foundation

enum AppNetworkError: Error {
    case invalidURL
    case connectionFailed(String)
    case httpNotOK
    case noData
}

final class SessionEndpoint {

    private let session: URLSession

    init() {
        session = SessionEndpoint.createSession()
    }

    private static func createSession() -> URLSession {

        let configuration = URLSessionConfiguration.ephemeral //We do not want OS to cache or persist
        configuration.allowsCellularAccess = true
        configuration.waitsForConnectivity = true
        configuration.networkServiceType = .responsiveData

        return URLSession(configuration: configuration)
    }

    func makeRequest<U: Decodable>(urlRequest: URLRequest,
                                             handler: @escaping (Result<U, ReachabilityError>) -> Void){

        let task = session.dataTask(with: urlRequest) { (data, response, error) in

            if let error = error {
                handler(.failure(ReachabilityError(type: "Network", title: "Error", status: -1, detail: error.localizedDescription)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                handler(.failure(ReachabilityError(type: "HTTP", title: "Error", status: -1, detail: "No response")))
                return
            }

            guard let data = data else {
                handler(.failure(ReachabilityError(type: "HTTP", title: "Error", status: httpResponse.statusCode, detail: "No data")))
                return
            }

            if (200...299).contains(httpResponse.statusCode),
               let dataModel = try? JSONDecoder().decode(U.self, from: data) {
                handler(.success(dataModel))
            } else {

                if let dataModel = try? JSONDecoder().decode(ReachabilityError.self, from: data) {
                        handler(.failure(dataModel))
                } else {
                    handler(.failure(ReachabilityError(type: "HTTP", title: "Error", status: httpResponse.statusCode, detail: "Unexpected data form Server for failure")))
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

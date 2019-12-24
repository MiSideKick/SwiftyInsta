//
//  EndpointHandler.swift
//  
//
//  Created by Stefano Bertagno on 24/12/2019.
//

import Foundation

public extension EndpointRepresentable {
    /// Fetch results at `Endpoint`.
    func fetch(_ handler: APIHandler, completion: @escaping (Result<DynamicResponse, Error>) -> Void) {
        handler.requests.request(DynamicResponse.self,
                                 method: .get,
                                 endpoint: self,
                                 process: { $0 },
                                 completion: completion)
    }
}

#if canImport(Combine)
import Combine

@available(iOS 13, *)
public extension EndpointRepresentable {
    /// Fetch results at `Endpoint`.
    func fetch(_ handler: APIHandler) -> AnyPublisher<DynamicResponse, Error> {
        Future<DynamicResponse, Error> { resolve in
            self.fetch(handler) { resolve($0) }
        }.eraseToAnyPublisher()
    }
}
#endif

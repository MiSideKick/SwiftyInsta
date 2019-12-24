//
//  EndpointHandler.swift
//  
//
//  Created by Stefano Bertagno on 24/12/2019.
//

import Foundation

public extension EndpointRepresentable {
    /// Handle.
    func handle(with handler: APIHandler) -> HandledEndpoint { .init(endpoint: self, handler: handler) }
}

/// A `struct` combining an endpoint and a the `APIHandler`.
public class HandledEndpoint {
    /// The endpoint.
    var endpoint: EndpointRepresentable
    /// The handler.
    weak var handler: APIHandler?

    /// Init.
    init(endpoint: EndpointRepresentable, handler: APIHandler) {
        self.endpoint = endpoint
        self.handler = handler
    }
}

public extension HandledEndpoint {
    /// Fetch results at `Endpoint`.
    func fetch(completion: @escaping (Result<DynamicResponse, Error>) -> Void) {
        guard let handler = handler else { return completion(.failure(GenericError.weakObjectReleased)) }
        handler.requests.request(DynamicResponse.self,
                                 method: .get,
                                 endpoint: endpoint,
                                 process: { $0 },
                                 completion: completion)
    }
}

#if canImport(Combine)
import Combine

/// A `struct` holding reference to a `Combine`-initiated response.
public struct HandledResponse {
    /// Request.
    public var request: HandledEndpoint
    /// Response.
    public var response: DynamicResponse
}

@available(iOS 13, *)
public extension HandledEndpoint {
    /// Fetch results at `Endpoint`.
    func fetch() -> Future<HandledResponse, Error> {
        Future { resolve in
            self.fetch { resolve($0.map { .init(request: self, response: $0) }) }
        }
    }
}
#endif

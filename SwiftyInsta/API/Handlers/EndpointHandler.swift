//
//  EndpointHandler.swift
//  
//
//  Created by Stefano Bertagno on 24/12/2019.
//

import Foundation

public extension EndpointRepresentable {
    /// Handle.
    func handle(with handler: APIHandler) -> HandledEndpoint {
        return .init(endpoint: self, handler: handler)
    }
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
    /// Ranki.
    public func rank() -> HandledEndpoint {
        guard let handler = handler, let token = handler.response?.storage?.rankToken else { return self }
        return .init(endpoint: endpoint.rank(token), handler: handler)
    }
}

public extension HandledEndpoint {
    /// Fetch results at `Endpoint`.
    func fetch(delay: ClosedRange<TimeInterval>? = nil, completion: @escaping (Result<DynamicResponse, Error>) -> Void) {
        guard let handler = handler else { return completion(.failure(GenericError.weakObjectReleased)) }
        handler.requests.request(DynamicResponse.self,
                                 method: .get,
                                 endpoint: endpoint,
                                 delay: delay,
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
        return Future { resolve in
            self.fetch(delay: 0...0) { resolve($0.map { .init(request: self, response: $0) }) }
        }
    }
    /// Fetch response at `Endpoint`.
    func response() -> AnyPublisher<DynamicResponse, Error> {
        return fetch().map(\.response).eraseToAnyPublisher()
    }
}

@available(iOS 13, *)
public extension Publisher where Output == DynamicResponse {
    /// Ignore errors.
    func ignoreErrors() -> AnyPublisher<Output, Never> {
        return self.catch { _ in Just(.none) }.eraseToAnyPublisher()
    }
    /// Get `User`.
    func user() -> AnyPublisher<User?, Failure> {
        return map { User(rawResponse: $0) }.eraseToAnyPublisher()
    }
    /// Get `Media`.
    func media() -> AnyPublisher<Media?, Failure> {
        return map { Media(rawResponse: $0) }.eraseToAnyPublisher()
    }
}
#endif

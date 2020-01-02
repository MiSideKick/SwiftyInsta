//
//  EndpointHandler.swift
//
//
//  Created by Stefano Bertagno on 24/12/2019.
//

import Foundation

// MARK: Generic
/// Fetch `HandledEndpoint`s.
public extension HandledEndpoint {
    /// Fetch results at `endpoint` using `handler`.
    func fetch(delay: ClosedRange<TimeInterval>? = nil,
               completion: @escaping (Result<DynamicResponse, Error>) -> Void) {
        guard let handler = handler else { return completion(.failure(GenericError.weakObjectReleased)) }
        handler.requests.request(DynamicResponse.self,
                                 method: .get,
                                 endpoint: endpoint,
                                 options: .validateResponse,
                                 delay: delay,
                                 process: { $0 },
                                 completion: completion)
    }
}

// MARK: Combine
#if canImport(Combine)
import Combine

/// A `struct` holding reference to a `Combine`-initiated response.
public struct HandledResponse {
    /// Request.
    public var request: HandledEndpoint
    /// Response.
    public var response: DynamicResponse
    
    /// Next.
    func next(_ nextId: String?) -> HandledEndpoint? {
        guard let nextId = nextId else { return nil }
        return .init(endpoint: request.endpoint.next(nextId), reference: request.reference)
    }
}

@available(iOS 13, *)
public extension HandledEndpoint {
    /// Fetch results at `Endpoint`.
    func fetch() -> AnyPublisher<HandledResponse, Error> {
        return Just(self)
            .setFailureType(to: Error.self)
            .flatMap { endpoint in
                Future { resolve in
                    endpoint.fetch(delay: 0...0, completion: resolve)
                }.map { .init(request: endpoint, response: $0) }
            }
            .eraseToAnyPublisher()
    }
    /// Fetch response at `Endpoint`.
    func response() -> AnyPublisher<DynamicResponse, Error> {
        return fetch().map(\.response).eraseToAnyPublisher()
    }
}

@available(iOS 13, *)
public extension Publisher where Output == HandledResponse, Failure == Error {
    /// Paginate. Return `nil` in `nextId` to stop pagination.
    func next(_ nextId: @escaping (Output) -> String?) -> AnyPublisher<Output, Failure> {
        return flatMap { output -> AnyPublisher<Output, Failure> in
            guard let next = nextId(output), let request = output.next(next) else {
                return Just(output).setFailureType(to: Failure.self).eraseToAnyPublisher()
            }
            // fetch next page.
            return Just(output)
                .setFailureType(to: Failure.self)
                .append(Deferred { request.fetch().next(nextId) })
                .eraseToAnyPublisher()
        }.eraseToAnyPublisher()
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

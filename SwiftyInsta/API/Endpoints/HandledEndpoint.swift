//
//  File.swift
//  
//
//  Created by Stefano Bertagno on 02/01/2020.
//

import Foundation

/// A `struct` holding reference to a request `Endpoint` and the `APIHandler`.
public struct HandledEndpoint {
    /// The endpoint.
    public var endpoint: EndpointRepresentable
    /// The handler reference.
    var reference: Identifier<User>
    /// The actual handler. `nil` if not found.
    public var handler: APIHandler? { return HandlerStorage.default.handlers.first(where: { $0.user?.identity == reference }) }
    
    // MARK: Endpoint
    /// The actual `Endpoint`.
    public var representation: LosselessEndpointRepresentable { return endpoint.representation }
    
    // MARK: Init
    /// Use `.handle(with:)` on `EndpointRepresentable`  instead.
    init?(endpoint: EndpointRepresentable, handler: APIHandler) {
        guard let reference = handler.user?.identity else { return nil }
        // add to the handler storage if needed.
        HandlerStorage.default.add(handler)
        // set properties.
        self.endpoint = endpoint
        self.reference = reference
    }
    /// Init.
    init(endpoint: EndpointRepresentable, reference: Identifier<User>) {
        self.endpoint = endpoint
        self.reference = reference
    }
    
    // MARK: Accessories
    /// Automatically set `rank`.
    public func rank() -> HandledEndpoint? {
        guard let rank = handler?.response?.storage?.rankToken else { return nil }
        return .init(endpoint: endpoint.rank(rank), reference: reference)
    }
}

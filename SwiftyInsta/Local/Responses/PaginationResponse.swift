//
//  File.swift
//  
//
//  Created by Stefano Bertagno on 11/12/2019.
//

import Foundation

public protocol PaginationProtocol {
    associatedtype Identifier: Hashable & LosslessStringConvertible
    var autoLoadMoreEnabled: Bool? { get }
    var moreAvailable: Bool? { get }
    var nextMaxId: Identifier? { get }
    var numResults: Int? { get }
}
public extension PaginationProtocol {
    var autoLoadMoreEnabled: Bool? { return nil }
    var moreAvailable: Bool? { return nil }
    var numResults: Int? { return nil }
}

public protocol NestedPaginationProtocol: PaginationProtocol {
    static var nextMaxIdPath: KeyPath<Self, Identifier?> { get }
}
public extension NestedPaginationProtocol {
    var nextMaxId: Identifier? { return self[keyPath: Self.nextMaxIdPath] }
}

protocol PaginatedResponse: ParsedResponse {
    var nextMaxId: String? { get }
}
extension PaginatedResponse {
    /// The `nextMaxId`.
    var nextMaxId: String? { return rawResponse.nextMaxId.string }
}
public struct AnyPaginatedResponse: PaginatedResponse {
    /// The `rawResponse`.
    public var rawResponse: DynamicResponse

    /// Init.
    public init(rawResponse: DynamicResponse) {
        self.rawResponse = rawResponse
    }

    // MARK: Codable
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawResponse = try DynamicResponse(data: container.decode(Data.self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawResponse.data())
    }
}


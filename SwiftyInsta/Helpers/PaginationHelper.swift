//
//  PaginationHelper.swift
//  SwiftyInsta
//
//  Created by Stefano Bertagno on 07/19/2019.
//  Copyright © 2019 Mahdi. All rights reserved.
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

public typealias PaginationUpdateHandler<R, P> = (
        _ update: P,
        _ inserting: [R],
        _ nextParameters: Bookmark,
        _ runningResponse: [R]
    ) -> Void
public typealias PaginationCompletionHandler<R> = (_ response: Result<[R], Error>, _ nextParameters: Bookmark) -> Void

class PaginationHelper: Handler {
    /// Get all pages matching criteria for `default` matching `ParsedResponse`.
    func request<Response, Page>(_ response: Response.Type,
                                 page: Page.Type,
                                 with paginationParameters: Bookmark,
                                 method: HTTPHelper.Method = .get,
                                 endpoint: @escaping (Bookmark) -> EndpointRepresentable,
                                 body: ((Bookmark) -> HTTPHelper.Body?)? = nil,
                                 headers: ((Bookmark) -> [String: String]?)? = nil,
                                 options: HTTPHelper.Options = [.validateResponse],
                                 delay: ClosedRange<Double>? = nil,
                                 next: @escaping (DynamicResponse) -> String? = { $0.nextMaxId.string },
                                 process: @escaping (DynamicResponse) -> Page? = Page.init,
                                 splice: @escaping (Page) -> [Response],
                                 update: PaginationUpdateHandler<Response, Page>?,
                                 completion: @escaping PaginationCompletionHandler<Response>) where Page: ParsedResponse {
        request(response,
                page: page,
                with: paginationParameters,
                method: method,
                endpoint: endpoint,
                body: body,
                headers: headers,
                options: options,
                delay: delay,
                nextPage: { next($0.rawResponse) },
                process: process,
                splice: splice,
                update: update,
                completion: completion)
    }
    /// Get all pages matching criteria.
    func request<Response, Page>(_ response: Response.Type,
                                 page: Page.Type,
                                 with paginationParameters: Bookmark,
                                 method: HTTPHelper.Method = .get,
                                 endpoint: @escaping (Bookmark) -> EndpointRepresentable,
                                 body: ((Bookmark) -> HTTPHelper.Body?)? = nil,
                                 headers: ((Bookmark) -> [String: String]?)? = nil,
                                 options: HTTPHelper.Options = [.validateResponse],
                                 delay: ClosedRange<Double>? = nil,
                                 nextPage: @escaping (Page) -> String?,
                                 process: @escaping (DynamicResponse) -> Page?,
                                 splice: @escaping (Page) -> [Response],
                                 update: PaginationUpdateHandler<Response, Page>?,
                                 completion: @escaping PaginationCompletionHandler<Response>) {
        // check for valid pagination.
        var reference = paginationParameters
        guard reference.pagesToLoad > 0 else {
            return completion(.failure(GenericError.custom("Can't load more.")), paginationParameters)
        }
        guard let handler = handler else {
            return completion(.failure(GenericError.weakObjectReleased), paginationParameters)
        }

        // responses.
        var responses = [Response]()
        // declare nested function to load current page.
        func requestNextPage() {
            let endpoint = endpoint(reference)
            handler.requests.request(page,
                                     method: method,
                                     endpoint: endpoint,
                                     body: body?(reference),
                                     headers: headers?(reference),
                                     options: options,
                                     delay: delay,
                                     process: process) { [weak self] in
                                        guard let handler = self?.handler else {
                                            return completion(.failure(GenericError.weakObjectReleased), reference)
                                        }
                                        // deal with cases.
                                        switch $0 {
                                        case .failure(let error): completion(.failure(error), reference)
                                        case .success(let page):
                                            // splice items.
                                            let new = splice(page)
                                            responses.append(contentsOf: new)
                                            // notify if needed.
                                            handler.settings.queues.response.async {
                                                update?(page, new, reference, responses)
                                            }
                                            // load more.
                                            guard reference.pagesToLoad > 0 else {
                                                return handler.settings.queues.response.async {
                                                    completion(.success(responses), reference)
                                                }
                                            }
                                            guard let nextReference = reference.next(nextPage(page)) else {
                                                return handler.settings.queues.response.async {
                                                    completion(.success(responses), reference)
                                                }
                                            }
                                            reference = nextReference
                                            requestNextPage()
                                        }
            }
        }
        // exhaust pages.
        requestNextPage()
    }
}

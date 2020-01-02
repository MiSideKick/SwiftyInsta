//
//  HTTPHelper.swift
//  SwiftyInsta
//
//  Created by Mahdi on 10/24/18.
//  V. 2.0 by Stefano Bertagno on 7/21/19.
//  Copyright © 2018 Mahdi. All rights reserved.
//

import Foundation

/// An _abstract_ `class` providing reference for all `*Handler`s.
class InstagramSession {
    /// The completion response.
    typealias CompletionResult = Result<(Data?, HTTPURLResponse?), Error>
    /// The completion handller.
    typealias CompletionHandler = (CompletionResult) -> Void

    /// The `HTTP` method.
    enum Method: String {
        case get = "GET"
        case post = "POST"
    }
    /// A body for the `URLRequest`.
    enum Body {
        case parameters([String: Any])
        case data(Data)
    }
    /// A list of options.
    struct Options: OptionSet {
        let rawValue: Int

        /// Validate response.
        static let validateResponse = Options(rawValue: 1 << 0)
        /// Deliver on response queue.
        static let deliverOnResponseQueue = Options(rawValue: 1 << 1)
        /// Start on request queue.
        static let startOnRequestQueue = Options(rawValue: 1 << 2)

        /// Default.
        static let `default`: Options = [.validateResponse, .deliverOnResponseQueue, .startOnRequestQueue]
    }

    /// The referenced handler.
    weak var handler: APIHandler!

    /// Init with `handler`.
    init(handler: APIHandler) {
        self.handler = handler
    }

    // MARK: Parse
    /// Parse a specific `Response`.
    func request<Response>(_ response: Response.Type,
                           method: Method,
                           endpoint: EndpointRepresentable,
                           body: Body? = nil,
                           headers: [String: String]? = nil,
                           options: Options = .default,
                           delay: ClosedRange<Double>? = nil,
                           process: @escaping (DynamicResponse) -> Response,
                           completion: @escaping(Result<Response, Error>) -> Void) {
        // fetch and parse response.
        request(response,
                method: method,
                endpoint: endpoint,
                body: body,
                headers: headers,
                options: options,
                delay: delay,
                process: { Optional.some(process($0)) },
                completion: completion)
    }
    /// Parse a specific `Decodable`.
    func request<Response>(_ response: Response.Type,
                           method: Method,
                           endpoint: EndpointRepresentable,
                           body: Body? = nil,
                           headers: [String: String]? = nil,
                           options: Options = .default,
                           delay: ClosedRange<Double>? = nil,
                           completion: @escaping(Result<Response, Error>) -> Void) where Response: Decodable {
        // fetch and parse response.
        request(response,
                method: method,
                endpoint: endpoint,
                body: body,
                headers: headers,
                options: options,
                delay: delay,
                process: { response -> Response? in
                    guard let data = try? response.data() else { return nil }
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    return try? decoder.decode(Response.self, from: data)
        },
                completion: completion)
    }
    /// Parse a specific `ParsedResponse`.
    func request<Response>(_ response: Response.Type,
                           method: Method,
                           endpoint: EndpointRepresentable,
                           body: Body? = nil,
                           headers: [String: String]? = nil,
                           options: Options = .default,
                           delay: ClosedRange<Double>? = nil,
                           completion: @escaping(Result<Response, Error>) -> Void) where Response: ParsedResponse {
        // fetch and parse response.
        request(response,
                method: method,
                endpoint: endpoint,
                body: body,
                headers: headers,
                options: options,
                delay: delay,
                process: Response.init,
                completion: completion)
    }
    /// Parse a specific optional `Response`.
    func request<Response>(_ response: Response.Type,
                           method: Method,
                           endpoint: EndpointRepresentable,
                           body: Body? = nil,
                           headers: [String: String]? = nil,
                           options: Options = .default,
                           delay: ClosedRange<Double>? = nil,
                           process: @escaping (DynamicResponse) -> Response?,
                           completion: @escaping(Result<Response, Error>) -> Void) {
        // fetch and parse response.
        fetch(method: method,
              url: Result { try endpoint.url() },
              body: body,
              headers: headers ?? [:],
              options: options,
              delay: delay) { [weak self] in
                guard let handler = self?.handler else { return completion(.failure(GenericError.weakObjectReleased)) }
                // consider response.
                let result = $0.flatMap { data, response -> Result<Response, Error> in
                    do {
                        guard let data = data else {
                            throw GenericError.custom("\(response?.url?.absoluteString ?? "_"). Invalid response. \(response?.statusCode ?? -1)")
                        }
                        // decode data.
                        guard let dynamicResponse = try? DynamicResponse(data: data), let value = process(dynamicResponse) else {
                            throw GenericError.custom([
                                "\(response?.url?.absoluteString ?? "—").",
                                "Invalid response.",
                                "Processing handler returned `nil`.",
                                "\(response?.statusCode ?? -1)"
                            ].joined(separator: "\n"))
                        }
                        // validate response.
                        guard !options.contains(.validateResponse) || response?.statusCode == 200 else {
                            throw GenericError.custom([
                                "\(response?.url?.absoluteString ?? "—").",
                                "Invalid response.",
                                "\(dynamicResponse.beautifiedDescription).",
                                "\(response?.statusCode ?? -1)"
                            ].joined(separator: "\n"))
                        }
                        // raise exception.
                        return .success(value)
                    } catch { return .failure(error) }
                }
                // notify results.
                if options.contains(.deliverOnResponseQueue) {
                    handler.settings.queues.response.async { completion(result) }
                } else {
                    completion(result)
                }
        }
    }

    // MARK: Fetch
    /// Accessory fetch async resource.
    func fetch(method: Method,
               url: URL,
               body: Body? = nil,
               headers: [String: String] = [:],
               options: Options = .default,
               delay: ClosedRange<Double>? = nil,
               completionHandler: @escaping CompletionHandler) {
        fetch(method: method,
              url: Result { url },
              body: body,
              headers: headers,
              options: options,
              delay: delay,
              completionHandler: completionHandler)
    }
    /// Fetch async resource.
    func fetch(method: Method,
               url: Result<URL, Error>,
               body: Body? = nil,
               headers: [String: String] = [:],
               options: Options = .default,
               delay: ClosedRange<Double>? = nil,
               completionHandler: @escaping CompletionHandler) {
        // prepare for requesting `url`.
        guard let content = try? url.get() else { return completionHandler(.failure(GenericError.invalidUrl)) }
        let delay = (delay ?? handler.settings.delay).flatMap { Double.random(in: $0) } ?? 0
        let request = URLRequest(url: content, method: body == nil ? method : .post, handler: handler)
            .headers(headers)
            .body(body)
        // fetch.
        if options == .startOnRequestQueue {
            handler.settings.queues.request.asyncAfter(deadline: .now()+delay) { [weak self] in
                guard let self = self else { return completionHandler(.failure(GenericError.weakObjectReleased)) }
                self.fetch(request: request, shouldWorkOnQueue: true, completion: completionHandler)
            }
        } else {
            fetch(request: request, shouldWorkOnQueue: false, completion: completionHandler)
        }
    }
    
    // MARK: Private
    /// Fetch request.
    private func fetch(request: URLRequest,
                       shouldWorkOnQueue: Bool,
                       completion: @escaping CompletionHandler) {
        guard let handler = handler else {
            return completion(.failure(GenericError.weakObjectReleased))
        }
        // return completion.
        func complete(data: Data?, response: URLResponse?, error: Error?) {
            switch error {
            case let error?: completion(.failure(error))
            default: completion(.success((data, response as? HTTPURLResponse)))
            }
        }
        // start task.
        handler.settings.session.dataTask(with: request) { data, response, error in
            if shouldWorkOnQueue {
                handler.settings.queues.working.async { complete(data: data, response: response, error: error) }
            } else {
                complete(data: data, response: response, error: error)
            }
        }.resume()
    }
}

extension URLRequest {
    /// Get the default request.
    fileprivate init(url: URL, method: InstagramSession.Method, handler: APIHandler) {
        self.init(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15)
        self.httpMethod = method.rawValue
        self.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: handler.response?.cookies ?? [])
        self.addValue(Headers.acceptLanguageValue, forHTTPHeaderField: Headers.acceptLanguageKey)
        self.addValue(Headers.igCapabilitiesValue, forHTTPHeaderField: Headers.igCapabilitiesKey)
        self.addValue(Headers.igConnectionTypeValue, forHTTPHeaderField: Headers.igConnectionTypeKey)
        self.addValue(Headers.contentTypeApplicationFormValue, forHTTPHeaderField: Headers.contentTypeKey)
        self.addValue(Headers.userAgentValue, forHTTPHeaderField: Headers.userAgentKey)
        // remove old values and updates with new one.
        handler.settings.headers.forEach { key, value in self.setValue(value, forHTTPHeaderField: key) }
    }

    /// Update headers.
    fileprivate func headers<S>(_ headers: [String: S]) -> URLRequest where S: LosslessStringConvertible {
        var request = self
        headers.forEach { request.allHTTPHeaderFields?.updateValue(String($0.value), forKey: $0.key) }
        return request
    }

    /// Set body.
    fileprivate func body(_ body: InstagramSession.Body?) -> URLRequest {
        var request = self
        switch body {
        case .parameters(let parameters):
            guard !parameters.isEmpty else { break }
            request.httpBody = parameters.map { $0.key+"=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        case .data(let data):
            request.httpBody = data
        default:
            request.httpBody = nil
        }
        return request
    }
}

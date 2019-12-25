//
//  HandlerStorage.swift
//  
//
//  Created by Stefano Bertagno on 25/12/2019.
//

import Foundation

/// A `class` holding reference to all initialized `APIHandler`s.
public class HandlerStorage {
    /// The default storage.
    public static let `default` = HandlerStorage()
    
    /// A strongly referenced array of authenticated `APIHandler`s.
    public var handlers: [APIHandler] = []
    
    // MARK: Restore
    /// Restore from a list of persisted `Authentication.Response` keys.
    public func restore(from keys: [String]) {
        keys.compactMap { Authentication.Response.persisted(with: $0) }
            .forEach {
                APIHandler().authenticate(with: .cache($0)) { [weak self] in
                    (try? $0.get()).flatMap { self?.add($0.1) }
                }
            }
    }
    
    // MARK: Change
    /// Add `APIHandler` to storage.
    public func add(_ handler: APIHandler) {
        guard handler.user != nil,
            !handlers.contains(where: { $0.user?.identity == handler.user?.identity }) else { return }
        // add to handlers.
        handlers.append(handler)
    }
    /// Remote `APIHandler` from storage.
    public func remove(_ handler: APIHandler) {
        guard let index = handlers.firstIndex(where: { $0.user?.identity == handler.user?.identity }) else { return }
        handlers.remove(at: index)
    }
}

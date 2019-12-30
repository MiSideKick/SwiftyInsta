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
    public var handlers: Set<APIHandler> = []
    
    // MARK: Restore
    /// Restore from a list of persisted `Authentication.Response` keys.
    public func restore(from keys: [String], completion: @escaping () -> Void) {
        // obtain authentication responses.
        let responses = keys.compactMap(Authentication.Response.persisted)
        // authenticate and complete.
        var fetched = 0
        self.handlers = Set(responses.map {
            let handler = APIHandler()
            handler.authenticate(with: .cache($0)) { _ in
                // increment and notify.
                fetched += 1
                if fetched == responses.count { completion() }
            }
            return handler
        })
    }
    
    // MARK: Change
    @discardableResult
    /// Add `APIHandler` to storage.
    public func add(_ handler: APIHandler) -> Bool {
        return handler.user != nil && handlers.insert(handler).inserted
    }
    
    @discardableResult
    /// Remove `APIHandler` from storage.
    public func remove(_ handler: APIHandler) -> APIHandler? {
        return handlers.remove(handler)
    }
}

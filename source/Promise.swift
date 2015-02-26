//
//  Promise.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 2/25/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import Foundation

typealias kPromiseFulfillClosure = (AnyObject?) -> AnyObject?
typealias kPromiseRejectClosure = (NSError) -> NSError

private enum PromiseState {
    case Pending([PromiseAction])
    case Fulfilled(AnyObject?)
    case Rejected(NSError)
}

class Promise {

    // MARK: Interface

    /**
    Initializes a new pending promise

    :returns: A pending promise with no chained promises
    */
    init() {
        state = .Pending([])
    }

    /**
    Initializes a new promise with a rejection error which also makes the promise state immutable.
    
    This can be useful when an async user code process needs to return a promise, but already
    knows there is a problem (such as with a failed network request, database query, etc.)

    :returns: A rejected promise with no chained promises
    */
    init(_ error:NSError) {
        state = .Rejected(error)
    }

    /**
    Initializes a new promise with a fulfilled value which also makes the promise state immutable.

    This can be useful when an async user code process needs to return a promise, but already
    has the result (such as with a successful network request, database query, etc.)

    :returns: A fulfilled promise with no chained promises
    */
    init(_ value:AnyObject?) {
        state = .Fulfilled(value)
    }

    /**
     Read-only property that is true if the promise is still pending
    */
    var isPending: Bool {
        get {
            switch (state) {
            case .Pending(let promiseActions):
                return true
            default:
                return false
            }
        }
    }

    /**
     Read-only property that is true if the promise has been fulfilled
    */
    var isFulfilled: Bool {
        get {
            switch (state) {
            case .Fulfilled(let value):
                return true
            default:
                return false
            }
        }
    }

    /**
     Read-only property that is true if the promise has been rejected
    */
    var isRejected: Bool {
        get {
            switch (state) {
            case .Rejected(let error):
                return true
            default:
                return false
            }
        }
    }

    /**
     Read-only property that is the fulfilled value if the promise has been fulfilled, nil otherwise
    */
    var value: AnyObject? {
        switch (state) {
        case .Fulfilled(let value):
            return value
        default:
            return nil
        }
    }

    /**
     Read-only property that is the rejection error if the promise has been rejected, nil otherwise
    */
    var error: NSError? {
        switch (state) {
        case .Rejected(let error):
            return error
        default:
            return nil
        }
    }

    /**
    If the promise is pending, then change its state to fulfilled using the supplied value
    and notify any chained promises that it has been fulfilled.  If the promise is in any other 
    state, no changes are made and any chained promises are ignored.

    :param: the fulfilled value to use for the promise
    */
    func fulfill(value: AnyObject?) {
        switch (state) {
        case .Pending(let promiseActions):
            state = .Fulfilled(value)
            for promiseAction in promiseActions {
                promiseAction.fulfill(value)
            }
        default:
            println("WARN: cannot fulfill promise, state already set to \(state)")
        }
    }

    /**
    If the promise is pending, then change its state to rejected using the supplied error
    and notify any chained promises that it has been rejected.  If the promise is in any other
    state, no changes are made and any chained promises are ignored.

    :param: the rejection error to use for the promise
    */
    func reject(error: NSError) {
        switch (state) {
        case .Pending(let promiseActions):
            state = .Rejected(error)
            for promiseAction in promiseActions {
                promiseAction.reject(error)
            }
        default:
            println("WARN: cannot reject promise, state already set to \(state)")
        }
    }

    /**
    'fulfill' and 'reject' closures may be added to a promise at any time. If the promise is
    eventually fulfilled, the fulfill closure will be called one time, and the reject closure
    will never be called. If the promise is eventually rejected, the reject closure will be
    called one time, and the fulfill closure will never be called.  If the promise remains in
    a pending state, neither closure will ever be called.
    
    This method may be called as many times as needed, and the appropriate closures will be
    called in the order they were added via the then method.
    
    If the promise is pending, then they will be added to the list of closures to be processed
    once  the promise is fulfilled or rejected in the future. 
    
    If the promise is already fulfilled, then the fulfill closure will be called immediately
    
    If the promise is already rejected, then if the reject closure exists, it will be called immediately

    :param: fulfill closure to call when the promise is fulfilled
            It can return:
                an NSError: it will cause any dependent promises to be rejected with this error
                a Promise: it will be chained to this instance
                any other value including nil: it will cause any dependent promises to be fulfilled with this value

    :param: optional rejection closure to call when the promise is rejected
    
    :returns: a new instance of a promise to which application code can add dependent promises (e.g. chaining)
    */
    func then(fulfill: kPromiseFulfillClosure, reject: kPromiseRejectClosure? = nil) -> Promise {
        let result = Promise()
        let promiseAction = PromiseAction(result, fulfill, reject)
        switch (state) {
        case .Pending(var promiseActions):
            promiseActions.append(promiseAction)
            state = .Pending(promiseActions)
        case .Fulfilled(let value):
            promiseAction.fulfill(value)
        case .Rejected(let error):
            promiseAction.reject(error)
        }
        return result
    }

    // MARK: implementation

    private var _state: PromiseState = .Pending([])
    private let stateSynchronizer = Synchronizer()

    private var state: PromiseState {
        get {
            var result: PromiseState!
            stateSynchronizer.synchronize({
                result = self._state
            })
            return result
        }
        set(newState) {
            stateSynchronizer.synchronize({
                self._state = newState
            })
        }
    }
    
}

private class PromiseAction {
    private let promise: Promise!
    private let fulfillClosure: kPromiseFulfillClosure!
    private let rejectClosure: kPromiseRejectClosure?

    init(_ promise: Promise, _ fulfillClosure: kPromiseFulfillClosure, rejectClosure: kPromiseRejectClosure?) {
        self.promise = promise
        self.fulfillClosure = fulfillClosure
        self.rejectClosure = rejectClosure
    }

    func fulfill(value: AnyObject?) {
        let fulfillResult: (AnyObject?) = fulfillClosure(value)
        if let promiseResult = fulfillResult as? Promise {
            promiseResult.then(
                { (value) -> AnyObject? in
                    self.promise.fulfill(value)
                    return value
                }, reject: { (error) -> NSError in
                    self.promise.reject(error)
                    return error
                }
            )
        } else if let errorResult = fulfillResult as? NSError {
            promise.reject(errorResult)
        } else {
            promise.fulfill(fulfillResult)
        }
    }

    func reject(error: NSError) {
        let rejectResult = (rejectClosure == nil) ? error : rejectClosure!(error)
        promise.reject(rejectResult)
    }

}
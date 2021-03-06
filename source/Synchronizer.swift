//
//  Synchronizer.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 2/25/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import Foundation

class Synchronizer {
    private let queue:dispatch_queue_t

    init() {
        let uuid = NSUUID().UUIDString
        self.queue = dispatch_queue_create("Sync.\(uuid)",nil)
    }

    init(queueName:String) {
        self.queue = dispatch_queue_create(queueName,nil)
    }

    init(queue:dispatch_queue_t) {
        self.queue = queue
    }

    func synchronize(closure:()->Void) {
        dispatch_sync(queue, {
            closure()
        })
    }

}
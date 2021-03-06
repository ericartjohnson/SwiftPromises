//
//  ChainedNetworkCallDemoViewController.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 3/1/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import UIKit

class ChainedNetworkCallDemoViewController: BaseDemoViewController {

    @IBOutlet var url1TextField:UITextField?
    @IBOutlet var url2TextField:UITextField?
    @IBOutlet var url3TextField:UITextField?
    @IBOutlet var url1StatusImageView:UIImageView?
    @IBOutlet var url2StatusImageView:UIImageView?
    @IBOutlet var url3StatusImageView:UIImageView?
    @IBOutlet var finalStatusImageView:UIImageView?
    @IBOutlet var stopOnErrorSwitch:UISwitch?

    override func viewWillAppear(animated: Bool) {
        url1TextField!.text = "http://cnn.com"
        url2TextField!.text = "http://apple.com"
        url3TextField!.text = "http://nytimes.com"

        super.viewWillAppear(animated)
    }

    override func clearStatus() {
        url1StatusImageView!.setStatus(nil)
        url2StatusImageView!.setStatus(nil)
        url3StatusImageView!.setStatus(nil)
        finalStatusImageView!.setStatus(nil)
    }

    override func readyToStart() -> Bool {
        return true
    }

    override func start() {
        clearStatus()
        clearLog()

        startActivityIndicator()

        loadURL1StepPromise().then(
            { [weak self] (value) -> AnyObject? in
                return self?.loadURL2StepPromise()
        } ).then(
            { [weak self] (value) -> AnyObject? in
                return self?.loadURL3StepPromise()
        }).then(
            { [weak self] (value) -> AnyObject? in
                self?.log("final success")
                self?.finalStatusImageView!.setStatus(true)
                self?.stopActivityIndicator()
                return value
            }, reject: { [weak self] (error) -> AnyObject? in
                self?.log("final error: \(error.localizedDescription)")
                self?.finalStatusImageView!.setStatus(false)
                self?.stopActivityIndicator()
                return error
        })

    }

    func loadURL1StepPromise() -> Promise {
        return loadURLStepPromise(url1TextField!.text, statusImageView:url1StatusImageView!)
    }

    func loadURL2StepPromise() -> Promise {
        return loadURLStepPromise(url2TextField!.text, statusImageView:url2StatusImageView!)
    }

    func loadURL3StepPromise() -> Promise {
        return loadURLStepPromise(url3TextField!.text, statusImageView:url3StatusImageView!)
    }

    func loadURLStepPromise(urlString:String?, statusImageView:UIImageView?) -> Promise {
        var url:NSURL? = (urlString == nil) ? nil : NSURL(string:urlString!)
        return loadURLPromise(url).then(
            { [weak self] (value) -> AnyObject? in
                statusImageView?.setStatus(true)
                var data:NSData? = value as? NSData
                self?.log("loaded \(data?.length) bytes from URL \(url)")
                return value
            }, reject: { [weak self] (error) -> AnyObject? in
                statusImageView?.setStatus(false)
                var stopOnError = true
                if let stopOnErrorSwitch = self?.stopOnErrorSwitch? {
                    stopOnError = stopOnErrorSwitch.on
                }
                if stopOnError {
                    self?.log("Stopping on error while loading URL \(url): \(error.localizedDescription)")
                    return error
                } else {
                    self?.log("Ignore error while loading URL \(url): \(error.localizedDescription)")
                    return nil // don't stop the chain
                }
            }
        )
    }

}

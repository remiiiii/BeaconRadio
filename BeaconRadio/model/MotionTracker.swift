//
//  MotionTracker.swift
//  BeaconRadio
//
//  Created by Thomas Bopst on 24/11/14.
//  Copyright (c) 2014 Thomas Bopst. All rights reserved.
//

import Foundation
import CoreMotion
import CoreLocation


class MotionTracker: NSObject, IMotionTracker, CLLocationManagerDelegate {
    
    private var operationQueue: NSOperationQueue = {
        let queue = NSOperationQueue()
        queue.qualityOfService = NSQualityOfService.Background

        return queue
    }()
    private var delegate: MotionTrackerDelegate?
    
    private var isTracking: Bool = false
    private lazy var pedometer = CMPedometer()
    private lazy var stepcounter = CMStepCounter()
    private lazy var motionactivity = CMMotionActivityManager()
    private lazy var deviceMotion = CMMotionManager()
    private lazy var locationManager = CLLocationManager()
    
    
    // Logger
    private let headingLogger = DataLogger(attributeNames: ["ts", "magneticHeading"])
    private let pedometerLogger = DataLogger(attributeNames: ["startTime", "endTime", "distance", "steps"])
    private let stepCounterLogger = DataLogger(attributeNames: ["ts", "steps"])
    private let deviceMotionLogger = DataLogger(attributeNames: ["ts", "m11", "m12", "m13", "m21", "m22", "m23", "m31", "m32", "m33"])
    private let activityLogger = DataLogger(attributeNames: ["startDate", "confidence", "unknown", "stationary", "walking", "running", "automotive", "cycling"])
    
    // Date Formatter
    private lazy var dateFormatter: NSDateFormatter = {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd_HH-mm"
        return dateFormatter
    }()
    
    override required init () {
        super.init()
        if !CMPedometer.isDistanceAvailable() {
            println("[ERROR] CMPedometer: Distance NOT available.")
        }
        
        if !CMPedometer.isStepCountingAvailable() {
            println("[ERROR] CMStepCounter: Stepcounting NOT available.")
        }
        
        if !CMMotionActivityManager.isActivityAvailable() {
            println("[ERROR] CMMotionActivityManager: MotionActivity NOT available.")
        }
        
        if UInt32(CMMotionManager.availableAttitudeReferenceFrames()) & CMAttitudeReferenceFrameXMagneticNorthZVertical.value == 0 {
            println("[ERROR] CMMotionAttitudeReferenceFrameXMagneticNorthZVertical NOT available.")
        }
        
        // CMDeviceMotion
        self.deviceMotion.showsDeviceMovementDisplay = true
        self.deviceMotion.deviceMotionUpdateInterval = 0.25
        
        
        // CLLocationManager authorization request
        self.locationManager.delegate = self
        self.locationManager.headingFilter = 2.5
        
        if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.Restricted ||
            CLLocationManager.authorizationStatus() == CLAuthorizationStatus.Denied {
                
                println("[ERROR] CLLocationManager: Authorization status \(CLLocationManager.authorizationStatus())")
                
        } else if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.NotDetermined {
            self.locationManager.requestWhenInUseAuthorization() // requestAlwaysAuthorization
        }
    }
    
    func startMotionTracking(delegate: MotionTrackerDelegate) {
        self.delegate = delegate
        
        let authStatus = CLLocationManager.authorizationStatus()
        
        self.headingLogger.start()
        self.pedometerLogger.start()
        self.stepCounterLogger.start()
        self.deviceMotionLogger.start()
        self.activityLogger.start()
        
        if  !self.isTracking && CLLocationManager.locationServicesEnabled() &&
            (authStatus == CLAuthorizationStatus.Authorized || authStatus == CLAuthorizationStatus.AuthorizedWhenInUse) {
                
                if CLLocationManager.headingAvailable() {
                    self.locationManager.startUpdatingHeading()
                }
                
                if CMPedometer.isDistanceAvailable() {
                    self.pedometer.startPedometerUpdatesFromDate(NSDate(), withHandler: { data, error in
                        if error != nil {
                            println("[ERROR] CMPedometer: \(error.description)")
                        } else {
                            
                            self.delegate?.motionTracker(self, didReceiveDistance: data.distance.doubleValue, withStartDate: data.startDate, andEndDate: data.endDate)
                            
                            self.operationQueue.addOperationWithBlock({
                                
                                let relativeStartDate = self.pedometerLogger.convertAbsoluteDateToRelativeDate(data.startDate)
                                let relativeEndDate = self.pedometerLogger.convertAbsoluteDateToRelativeDate(data.endDate)
                                
                                let res = self.pedometerLogger.log([["startTime":"\(relativeStartDate)", "endTime":"\(relativeEndDate)", "distance":"\(data.distance)", "steps":"\(data.numberOfSteps)"]])
//                            Logger.sharedInstance.log(message: data.description)
                            })
                            
                        }
                    })
                }
                
                if CMStepCounter.isStepCountingAvailable() {
                    self.stepcounter.startStepCountingUpdatesToQueue(operationQueue, updateOn: 1, withHandler: {numberOfSteps, timestamp, error in
                        if error != nil {
                            println("[ERROR] CMStepCounter: \(error.description)")
                        } else {
                            // TODO
                            let relativeTs = self.stepCounterLogger.convertAbsoluteDateToRelativeDate(timestamp)
                            
                            self.stepCounterLogger.log([["ts":"\(relativeTs)", "steps":"\(numberOfSteps)"]])
                        }
                    })
                }
                
                if CMMotionActivityManager.isActivityAvailable() {
                    self.motionactivity.startActivityUpdatesToQueue(operationQueue, withHandler: {activity in
                        
                        self.delegate?.motionTracker(self, didReceiveMotionActivityData: activity.stationary, withConfidence: activity.confidence, andStartDate: activity.startDate)
                        
                        let relativeTs = self.activityLogger.convertAbsoluteDateToRelativeDate(activity.startDate)
                        
                        let res = self.activityLogger.log([["startDate":"\(relativeTs)", "confidence":"\(activity.confidence.rawValue)", "unknown":"\(activity.unknown)", "stationary":"\(activity.stationary)", "walking":"\(activity.walking)", "running":"\(activity.running)", "automotive":"\(activity.automotive)", "cycling":"\(activity.cycling)"]])
                    })
                }
                if UInt32(CMMotionManager.availableAttitudeReferenceFrames()) & CMAttitudeReferenceFrameXMagneticNorthZVertical.value > 0 {
                    self.deviceMotion.startDeviceMotionUpdatesUsingReferenceFrame(CMAttitudeReferenceFrameXMagneticNorthZVertical, toQueue: operationQueue, withHandler: {motion, error in
                        if error != nil {
                            println("[ERROR] CMDeviceMotion: \(error.description)")
                        } else if motion != nil {
                            
                            // http://stackoverflow.com/questions/9341223/how-can-i-get-the-heading-of-the-device-with-cmdevicemotion-in-ios-5/11299471#11299471
                            
                            let rMatrix = motion.attitude.rotationMatrix
                            
                            let timestamp = NSDate()
                            
                            if rMatrix.m22 != 0 && rMatrix.m12 != 0 {
                                let heading = (M_PI + atan2(rMatrix.m22, rMatrix.m12)) * 180.0 / M_PI // in compass deg
                                
                                //let heading = (motion.attitude.yaw + M_PI) % (2 * M_PI) // yaw: -PI/2 = North, PI = East, PI/2 = South, 0 = West
                                
                                self.delegate?.motionTracker(self, didReceiveHeading: heading, withTimestamp: timestamp)
                                Logger.sharedInstance.log(message: "Heading (CM): \(heading) deg")
                            }
                            
                            let relativeTs = self.headingLogger.convertAbsoluteDateToRelativeDate(timestamp)
                            self.deviceMotionLogger.log([["ts":"\(relativeTs)",
                                "m11":"\(rMatrix.m11)", "m12":"\(rMatrix.m12)", "m13":"\(rMatrix.m13)",
                                "m21":"\(rMatrix.m21)", "m22":"\(rMatrix.m22)", "m23":"\(rMatrix.m23)",
                                "m31":"\(rMatrix.m31)", "m32":"\(rMatrix.m32)", "m33":"\(rMatrix.m33)"]])
                        }
                        
                    })
                }
                self.isTracking = true
        }
    }
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if (!(status == CLAuthorizationStatus.Authorized || status == CLAuthorizationStatus.AuthorizedWhenInUse) && isTracking) {
            self.stopMotionTracking()
            println("[ERROR] CLLocationManager: Authorization status \(CLLocationManager.authorizationStatus())")
        }
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateHeading newHeading: CLHeading!) {
        
//        self.delegate?.motionTracker(self, didReceiveHeading: newHeading.magneticHeading, withTimestamp: newHeading.timestamp)
        
        self.operationQueue.addOperationWithBlock({
            
            let relativeTs = self.headingLogger.convertAbsoluteDateToRelativeDate(newHeading.timestamp)
            
           let res = self.headingLogger.log([["ts":"\(relativeTs)", "magneticHeading":"\(newHeading.magneticHeading)"]])
        })
    }
    
//    func locationManagerShouldDisplayHeadingCalibration(manager: CLLocationManager!) -> Bool {
//        return true
//    }
    
    func stopMotionTracking() {
        if isTracking {
            self.pedometer.stopPedometerUpdates()
            self.stepcounter.stopStepCountingUpdates()
            self.motionactivity.stopActivityUpdates()
            self.locationManager.stopUpdatingHeading()
            self.deviceMotion.stopDeviceMotionUpdates()
            
            let dirs : [String]? = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true) as? [String]
            
            if let directories = dirs {
                let dir = directories[0]; //documents directory
                let headingPath = dir.stringByAppendingPathComponent("\(self.dateFormatter.stringFromDate(NSDate()))_Heading.csv");
                self.headingLogger.save(dataStoragePath: headingPath, error: nil)
                
                let pedometerPath = dir.stringByAppendingPathComponent("\(self.dateFormatter.stringFromDate(NSDate()))_Pedometer.csv");
                self.pedometerLogger.save(dataStoragePath: pedometerPath, error: nil)
                
                let stepCounterPath = dir.stringByAppendingPathComponent("\(self.dateFormatter.stringFromDate(NSDate()))_StepCounter.csv");
                self.stepCounterLogger.save(dataStoragePath: stepCounterPath, error: nil)
                
                let deviceMotionPath = dir.stringByAppendingPathComponent("\(self.dateFormatter.stringFromDate(NSDate()))_DeviceMotion.csv");
                self.deviceMotionLogger.save(dataStoragePath: deviceMotionPath, error: nil)
                
                let activityPath = dir.stringByAppendingPathComponent("\(self.dateFormatter.stringFromDate(NSDate()))_Activity.csv");
                self.activityLogger.save(dataStoragePath: activityPath, error: nil)
            }
            self.isTracking = false
        }
    }
    
}
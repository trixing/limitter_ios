//
//  HealthKitManager.swift
//  limitter_ios
//
//  Created by Jan Dittmer on 10/22/16.
//  Copyright © 2016 Jan Dittmer. All rights reserved.
//

import Foundation

import HealthKit

class HealthKitManager {
    
    let healthKitStore: HKHealthStore = HKHealthStore()
    
    func authorizeHealthKit(completion: ((_ success: Bool, _ error: Error?) -> Void)!) {
        
        // State the health data type(s) we want to read from HealthKit.
        //let healthDataToRead = Set(arrayLiteral: HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.height)!)
        //let healthDataToRead = nil
        // State the health data type(s) we want to write from HealthKit.
        let healthDataToWrite = Set(arrayLiteral: HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!)
        
        // Just in case OneHourWalker makes its way to an iPad...
        if !HKHealthStore.isHealthDataAvailable() {
            print("Can't access HealthKit.")
        }
        
        // Request authorization to read and/or write the specific data.
        healthKitStore.requestAuthorization(toShare: healthDataToWrite, read: nil) { (success, error) -> Void in
            completion?(success, error)
        }
    }

    
    func saveGlucose(glucose: Double, date: Date ) {
        
        // Set the quantity type to bloodGlucose.
        let glucoseType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
        
        // Set the unit of measurement (mg/dl).
        let glucoseQuantity = HKQuantity(unit: HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.literUnit(with: .deci)), doubleValue: glucose)
        
        // Set the official Quantity Sample.
        let glucoseSample = HKQuantitySample(type: glucoseType!, quantity: glucoseQuantity, start: date, end: date)
        
        // Save the distance quantity sample to the HealthKit Store.
        healthKitStore.save(glucoseSample, withCompletion: { (success, error) -> Void in
            if( error != nil ) {
                print(error)
            } else {
                print("The sample has been recorded! Better go check!")
            }
        })
    }
}

//
//  HealthKitManager.swift
//  limitter_ios
//
//  Created by Jan Dittmer on 10/22/16.
//  Copyright © 2016 Jan Dittmer. All rights reserved.
//

import Foundation

import HealthKit

//import Crypto


public enum UploadError: Error {
    case httpError(status: Int, body: String)
    case missingTimezone
    case invalidResponse(reason: String)
    case unauthorized
}
/*
extension String {
    func sha1() -> String {
        let data = self.data(using: String.Encoding.utf8)!
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0, CC_LONG(data.count), &digest)
        }
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joined()
    }
}
*/
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

    
    func saveGlucose(glucose: Int, date: Date, raw_sensor_value: Int, minutes: Int, battery_mv: Int ) {
        
        // Set the quantity type to bloodGlucose.
        let glucoseType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
        
        // Set the unit of measurement (mg/dl).
        let glucoseQuantity = HKQuantity(unit: HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.literUnit(with: .deci)), doubleValue: Double(glucose))
        
        let metadata = [
            "raw_sensor_value": raw_sensor_value,
            "minutes_since_sensor_start": minutes,
            "transmitter_battery_mv": battery_mv,
        ] as [String : Any]
        // Set the official Quantity Sample.
        let glucoseSample = HKQuantitySample(type: glucoseType!, quantity: glucoseQuantity, start: date, end: date, metadata: metadata)
        
        // Save the quantity sample to the HealthKit Store.
        healthKitStore.save(glucoseSample, withCompletion: { (success, error) -> Void in
            if( error != nil ) {
                print(error as Any!)
            } else {
                print("The sample has been recorded! Better go check!")
            }
        })
    }
    

}

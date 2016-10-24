//
//  ViewController.swift
//  limitter_ios
//
//  Created by Jan Dittmer on 10/14/16.
//  Copyright © 2016 Jan Dittmer. All rights reserved.
//

import UIKit
import CoreBluetooth
import HealthKit


class ViewController: UIViewController,  CBCentralManagerDelegate, CBPeripheralDelegate {
    // MARK: Properties
    
    @IBOutlet weak var TextUp: UITextField!
    @IBOutlet weak var TextLow: UITextField!
    @IBOutlet weak var ListBox: UITableView!
    
    private      var centralManager:   CBCentralManager!
    private      var activePeripheral: CBPeripheral?
    
    let LIMITTER_NAME = "LimiTTer"
    let LIMITTER_SERVICE_UUID = "FFE0"
    let LIMITTER_CHAR_UUID = "FFE1"

    let LIMITTER_DEVICE_UUID = "1F36015B-21D2-4265-89DA-561B2029E165"
    
    let healthManager:HealthKitManager = HealthKitManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        print("Hello viewDidLoad")
  //      self.centralManager.scanForPeripherals(withServices: services, options: nil)
  //      self.centralManager.scanForPeripherals(withServices: nil, options: nil)
        getHealthKitPermission()

        
    }
    
    func getHealthKitPermission() {
        
        // Seek authorization in HealthKitManager.swift.
        healthManager.authorizeHealthKit { (authorized,  error) -> Void in
            if authorized {
                print("Got permission for HK.")

            } else {
                if error != nil {
                    print(error)
                }
                print("Permission denied.")
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch(central.state){
        case .poweredOn:
            print("Bluetooth is powered ON")
            TextUp.text = "ON"
            let services:[CBUUID] = [CBUUID(string: LIMITTER_SERVICE_UUID)]

            //self.centralManager.scanForPeripherals(withServices: nil, options:nil)
            self.centralManager.scanForPeripherals(withServices: services, options:nil)

        case .poweredOff:
            print("Bluetooth is powered OFF")
        case .resetting:
            print("Bluetooth is resetting")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .unknown:
            print("Bluetooth is unknown")
        case .unsupported:
            print("Bluetooth is not supported")
        }
    }
    
    func centralManager(_ central: CBCentralManager,  didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        print("Discovered Something \(peripheral.name) \(peripheral.state) \(rssi) \(peripheral.identifier)")
        TextUp.text = "DISC"
        if peripheral.name == "LimiTTer" {
            TextLow.text = peripheral.name
            self.activePeripheral = peripheral

            if peripheral.state == .disconnected  {
                print("Connecting to LimiTTer")
                self.activePeripheral = peripheral
                central.connect(peripheral , options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey : NSNumber(value: true)])
            } else if peripheral.state == .connected {
                self.activePeripheral = peripheral
            } else {
                print("Unknown device state")
            }
            peripheral.delegate = self
            central.stopScan()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect: CBPeripheral, error: Error?) {
        print("123")
        TextUp.text = "CONN FAIL"

        if error != nil {
            print("Error connecting to peripheral: \(error?.localizedDescription)")
            return
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Peripheral connected.")
        TextUp.text = "CONN SUCCESS"
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    @objc(centralManager:didDisconnectPeripheral:error:) func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Peripheral disconnected.")
        self.activePeripheral = nil
        // TODO(jdi): Start scanning again.
    }

    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("456")
        TextUp.text = "SERVICE"

        if error != nil {
            print("Error discovering services \(error?.localizedDescription)")
            return
        }
        
        for service: CBService in peripheral.services! {
            print("Discover characteristics \(service.uuid)")
            if service.uuid == CBUUID(string: LIMITTER_SERVICE_UUID) {
                // TODO should only list characteristics we want
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("789")
        TextUp.text = "CHAR"

        if error != nil {
            print("Error discovering characteristics \(error?.localizedDescription)")
            return
        }
        
        for characteristic: CBCharacteristic in service.characteristics! {
            print("Char \(characteristic.uuid)")
            if characteristic.uuid == CBUUID(string: LIMITTER_CHAR_UUID) {
                //peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
                // for some devices, you can skip readValue() and print the value here
            }
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("UPDATE NOTIF CHANGE")

    }
    
    @objc(peripheral:didUpdateValueForCharacteristic:error:) func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("999")
        TextUp.text = "VAL"

        if characteristic.uuid == CBUUID(string: LIMITTER_CHAR_UUID) {
            print("Read value")
            let str = String(data: characteristic.value!, encoding: String.Encoding.ascii)
            print(str)
            TextLow.text = str
            let arr = str?.components(separatedBy: " ")
            if (arr?.count)! >= 5 {
                let glucose = Int((arr?[0])!)
                let glucose_trend = Int((arr?[1])!)

                let bat_mv = Int((arr?[2])!)
                let bat_percent = Int((arr?[3])!)
                let minutes = Int((arr?[4])!)

                if glucose != nil && bat_mv != nil && bat_percent != nil  && (glucose?)! > 1 {
                    let newstr = "\(glucose) \(bat_mv) \(bat_percent)"
                    TextUp.text = newstr
                    healthManager.saveGlucose(glucose: Double(glucose!), date: Date())

                    return  // success
                }
            }
            TextUp.text = "Error decoding"
        }
    }
    
}


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
import UserNotifications
import UserNotificationsUI

// http://sketchytech.blogspot.de/2016/02/resurrecting-commoncrypto-in-swift-for.html
extension String {
    
    func digest(length:Int32, gen:(_ data: UnsafeRawPointer, _ len: CC_LONG, _ md: UnsafeMutablePointer<UInt8>) -> UnsafeMutablePointer<UInt8>) -> String {
        var cStr = [UInt8](self.utf8)
        var result = [UInt8](repeating:0, count:Int(length))
        _ = gen(&cStr, CC_LONG(cStr.count), &result)
        
        let output = NSMutableString(capacity:Int(length))
        
        for r in result {
            output.appendFormat("%02x", r)
        }
        
        return String(output)
    }
    
    func sha1() -> String {
        return self.digest(length: CC_SHA1_DIGEST_LENGTH, gen: {(data, len, md) in CC_SHA1(data,len,md)})
    }
    
}

class ViewController: UIViewController,  CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDataSource, UITableViewDelegate {


    // MARK: Properties
    

    @IBOutlet weak var ListBox: UITableView!
    @IBOutlet weak var labelBloodGlucose: UILabel!
    @IBOutlet weak var labelBattery: UILabel!
    @IBOutlet weak var labelMinutes: UILabel!
    @IBOutlet weak var labelUpload: UILabel!
    @IBOutlet weak var labelUpdated: UILabel!
    @IBOutlet weak var labelBluetooth: UILabel!
    @IBOutlet weak var labelBloodGlucoseBig: UILabel!
    
    private      var centralManager:   CBCentralManager!
    private      var activePeripheral: CBPeripheral?
    let GLUCOSE_SCALER = 10.3

    let LIMITTER_NAME = "LimiTTer"
    let LIMITTER_SERVICE_UUID = "FFE0"
    let LIMITTER_CHAR_UUID = "FFE1"

    let LIMITTER_DEVICE_UUID = "1F36015B-21D2-4265-89DA-561B2029E165"
    
    let healthManager:HealthKitManager = HealthKitManager()
    let cellIdentifier = "CellIdentifier"

    let centralManagerIdentifier = "CMoi"
    var history: [String] = []
    let defaults = UserDefaults.standard
    private let defaultNightscoutEntriesPath = "/api/v1/entries"
   
    private func settingGetBTName() -> String {
        let str = defaults.string(forKey: "bluetooth_name")
        if (str == nil) {
            return LIMITTER_NAME
        } else {
            return str!
        }
    }
    
    private func settingGetBTUid() -> String? {
        return defaults.string(forKey: "bluetooth_uid")
    }
    
    private func settingGetGlucoseScaler() -> Double {
        let val = defaults.double(forKey: "glucose_scaler")
        if (val == 0) {
            return GLUCOSE_SCALER
        }
        return val
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.centralManager = CBCentralManager(
            delegate: self, queue: DispatchQueue.main, options: [ CBCentralManagerOptionRestoreIdentifierKey:
                centralManagerIdentifier ])
        getHealthKitPermission()
        log(str: "Started")
        Timer.scheduledTimer(timeInterval: 10, target:self, selector: #selector(ViewController.updateDisplay), userInfo: nil, repeats: true)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (granted: Bool, error: Error?) in
            // Do something here
            if (granted) {
                self.log(str: "Notification successful.")
            } else {
                self.log(str: "Notifications not allowed.")
            }
        }
    }
    
    private func glucoseNotification(_ glucose: String, _ badge: Int) {
        let content = UNMutableNotificationContent()
        
        content.title = "Glucose Value"
        content.body = glucose
        // content.sound = UNNotificationSound.default()
        content.badge = NSNumber(value: badge)
        
        // Deliver the notification in five seconds.
        //let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: 1, repeats: false)
       // let request = UNNotificationRequest.init(identifier: "FiveSecond", content: content, trigger: trigger)
        let request = UNNotificationRequest.init(identifier: "Now", content: content, trigger: nil)
       
        // Schedule the notification.
        let center = UNUserNotificationCenter.current()
        // remove old notifications
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        // post new one
        center.add(request) { (error) in
            //self.log(str: error)
        }
        
    }
    private func log(str: String) {
        let currentDateTime = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let newstr = formatter.string(from: currentDateTime) + " " + str
        history.insert(newstr, at: 0)
        print("LOG \(newstr)")
        ListBox.reloadData()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return history.count
    }

    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath as IndexPath)
        
        // Fetch Line
        let line = history[indexPath.row]
        
        // Configure Cell
        cell.textLabel?.text = line
        
        return cell
    }
    
    func getHealthKitPermission() {
        
        // Seek authorization in HealthKitManager.swift.
        healthManager.authorizeHealthKit { (authorized,  error) -> Void in
            if authorized {
                print("Got permission for HK.")

            } else {
                if error != nil {
                    print(error as! String)
                }
                print("HK Permission denied.")
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func startScan() {
        let services:[CBUUID] = [CBUUID(string: LIMITTER_SERVICE_UUID)]
        
        //self.centralManager.scanForPeripherals(withServices: nil, options:nil)
        self.centralManager.scanForPeripherals(withServices: services, options:nil)
        self.bluetooth_state = "Scan"

    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch(central.state){
        case .poweredOn:
            log(str: "Bluetooth is powered ON")
            self.bluetooth_state = "On"
            self.startScan()

        case .poweredOff:
            log(str: "Bluetooth is powered OFF")
            self.bluetooth_state = "Off"

        case .resetting:
            log(str: "Bluetooth is resetting")
            self.bluetooth_state = "Reset"

        case .unauthorized:
            log(str: "Bluetooth is unauthorized")
            self.bluetooth_state = "UnAuth"

        case .unknown:
            log(str: "Bluetooth is unknown")
            self.bluetooth_state = "Unknown"

        case .unsupported:
            log(str: "Bluetooth is not supported")
            self.bluetooth_state = "NoSupport"

        }
    }
    
    func centralManager(_ central: CBCentralManager,  didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        log(str: "Discovered \(peripheral.name) \(peripheral.state) \(rssi) \(peripheral.identifier)")
        let bt_uid = self.settingGetBTUid()
        var found : Bool = false
        if bt_uid != nil {
            if bt_uid == peripheral.identifier.uuidString {
                found = true
            }
        } else if peripheral.name == self.settingGetBTName() {
            found = true
        }
        
        if found {
            if peripheral.state == .disconnected  {
                log(str: "Connecting to \(peripheral.name) \(peripheral.identifier)")
                self.defaults.set(peripheral.identifier.uuidString, forKey: "bluetooth_uid")
                self.activePeripheral = peripheral
                central.connect(peripheral , options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey : NSNumber(value: true)])
            } else if peripheral.state == .connected {
                log(str: "Already connected to \(peripheral.name)  \(peripheral.identifier)")
                self.activePeripheral = peripheral
            } else {
                log(str: "Unknown device state")
            }
            peripheral.delegate = self
            central.stopScan()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect: CBPeripheral, error: Error?) {
        log(str: "Connection failed")
        self.bluetooth_state = "ConnFail"

        if error != nil {
            log(str: "Error connecting to peripheral: \(error?.localizedDescription)")
            return
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log(str: "Peripheral connected.")
        self.bluetooth_state = "ConnOK"
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState state:  [String : Any]){
        log(str: "Restoring state")
        self.centralManager = central
        let peripherals:[CBPeripheral] = state[CBCentralManagerRestoredStatePeripheralsKey] as! [CBPeripheral]!
        //let peripherals = dict[state[CBCentralManagerRestoredStatePeripheralsKey]]
        if (peripherals.count == 0) {
            self.startScan()
        }
        for peripheral: CBPeripheral in peripherals {
            log(str: "Rediscover characteristics of peripheral \(peripheral.identifier)")
            self.activePeripheral = peripheral
            peripheral.delegate = self
            for service: CBService in peripheral.services! {
                log(str: "Discover characteristics \(service.uuid)")
                if service.uuid == CBUUID(string: LIMITTER_SERVICE_UUID) {
                    // TODO should only list characteristics we want
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
            break
        }
    }
    
    @objc(centralManager:didDisconnectPeripheral:error:) func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log(str: "Peripheral disconnected, reconnecting")
        self.bluetooth_state = "Discon"

        //self.activePeripheral = nil
        central.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey : NSNumber(value: true)])
        //[central connectPeripheral:peripheral options:nil];

    }

    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {

        if error != nil {
            log(str: "Error discovering services \(error?.localizedDescription)")
            self.activePeripheral = nil
            self.bluetooth_state = "ErrServ"

            return
        }
        
        for service: CBService in peripheral.services! {
            log(str: "Discover characteristics \(service.uuid)")
            if service.uuid == CBUUID(string: LIMITTER_SERVICE_UUID) {
                // TODO should only list characteristics we want
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        log(str: "Characteristics")
        if error != nil {
            log(str: "Error discovering characteristics \(error?.localizedDescription)")
            self.bluetooth_state = "ErrChar"

            return
        }
        
        for characteristic: CBCharacteristic in service.characteristics! {
            log(str: "Char \(characteristic.uuid)")
            if characteristic.uuid == CBUUID(string: LIMITTER_CHAR_UUID) {
                //peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
                // for some devices, you can skip readValue() and print the value here
            }
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        log(str: "UpdateNotificationState")
        self.bluetooth_state = "Listening"
    }
    
    func updateDisplay() {
        let now = Date()
        if self.last_nightscout_upload != nil {
            let difference = Calendar.current.dateComponents([.minute], from: self.last_nightscout_upload!, to: now)

            self.labelUpload.text = "\(difference.minute!)m"
        }
        
        if self.last_update != nil {
            let difference = Calendar.current.dateComponents([.minute], from: self.last_update!, to: now)
            self.labelUpdated.text = "\(difference.minute!)m"
            
            if (difference.minute! < 5) {
                self.labelBattery.text = "\(self.last_bat_mv)"
                self.labelMinutes.text = "\(self.last_minutes)"
                self.labelBloodGlucose.text = "\(self.last_glucose)"
                self.labelBloodGlucoseBig.text = "\(self.last_glucose)"
                self.glucoseNotification("\(self.last_glucose)", self.last_glucose)
            } else {
                self.labelBattery.text = "[\(self.last_bat_mv)]"
                self.labelMinutes.text = "[\(self.last_minutes)]"
                self.labelBloodGlucose.text = "TOO OLD"
                self.labelBloodGlucose.text = "OLD"
                self.glucoseNotification("Glucose Value stale", 0)

            }
        }
        //self.glucoseNotification("Glucose Startup", 0)

        self.labelBluetooth.text = self.bluetooth_state
 
    }
    var last_status = ""
    private var last_update: Date? = nil
    private var last_glucose = 0
    private var last_minutes = 0
    private var last_bat_mv = 0
    private var bluetooth_state = ""
    
    func decodeSensor(_ str: String) -> String {
        let arr = str.components(separatedBy: " ")
        if arr.count < 2 {
            return "Wrong component length \(arr.count)"
        }

        let bat_mv = Int(arr[1])
        if bat_mv == nil {
             return "Battery value invalid! \(bat_mv)"
        }
        self.last_bat_mv = bat_mv!
        if bat_mv! < 3400 {
            return "Battery soon low! \(bat_mv!)"
        }
        
        let status = arr[0]
        if status == last_status {
            return "Same status \(status)"
        }
        last_status = status

        let minutes = Int(status)
        if minutes != nil {
            var raw: [Int] = []
            var raw_trend = 0
            for i in 2 ..< arr.count {
                let value = Int(arr[i])!
                raw.append(value)
                if (raw.count > 1) {
                    raw_trend += raw[raw.count-2] - raw[raw.count-1]
                }
            }
            var trend = 0.0
            let glucose_scaler = self.settingGetGlucoseScaler()
            if raw.count > 1 {
                trend = Double(raw_trend) / Double(raw.count - 1) / glucose_scaler
            }
            let raw_sensor_value = raw[0]
            let glucose = Int(Double(raw_sensor_value) / glucose_scaler)

            self.last_update = Date()
            self.last_glucose = glucose
            self.last_minutes = minutes!
            let result = "GLUCOSE \(glucose) TREND \(trend) BATTERY \(bat_mv!) MINUTES \(minutes!)"
            if (glucose < 10) {
                return "Glucose value too value - sensor defect (\(glucose)) ??"
            }
            healthManager.saveGlucose(glucose: glucose, date: self.last_update!, raw_sensor_value: raw_sensor_value,
                                      minutes: minutes!, battery_mv: bat_mv!)
            postGlucose(glucose, self.last_update!)
            return result // success
        } else {
            return "Error decoding status to minutes \(status)"
        }
        
    }

    @objc(peripheral:didUpdateValueForCharacteristic:error:) func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == CBUUID(string: LIMITTER_CHAR_UUID) {
            let rx = String(data: characteristic.value!, encoding: String.Encoding.ascii)!
            log(str: "RX " + rx)

            let msg = decodeSensor(rx)
            log(str: msg)
            self.updateDisplay()
        } else {
            log(str: "Discard value \(characteristic.uuid)")
        }
    }
    
    
    var entries: [[String: Any]] = []
    private var last_nightscout_upload: Date? = nil

    public func postGlucose(_ glucose: Int, _ date: Date) {
        
        // TODO: Should only accept meter messages from specified meter ids.
        // Need to add an interface to allow user to specify linked meters.
        /*
         entry["previousSGV"] = previousGlucose
         default:
         entry["previousSGVNotActive"] = true
         */
        let epochTime = date.timeIntervalSince1970 * 1000
        let formatterISO8601 = DateFormatter()
        
        
        let entry: [String: Any] = [
            "date": epochTime,
            "dateString": formatterISO8601.string(from: date),
            "sgv": glucose,
            "device": "LimiTTer-iOS",
            "type": "sgv"
        ]
        self.entries.append(entry)
        
        let success = postToNS(entries as [Any])
        if (success) {
            self.entries.removeAll()
            self.last_nightscout_upload = Date()
        }
        
    }
    
    // rileylink_ios, NightscoutUploader, the essential parts
    func postToNS(_ json: Any?) -> Bool {
        let endpoint = defaultNightscoutEntriesPath
        let enabled = self.defaults.bool(forKey: "nightscout_enabled")
        if (enabled == false) {
            self.log(str: "Nightscout not enabled.")
            return false
        }
        let apiURL = self.defaults.url(forKey: "nightscout_server")
        let apiStringSecret = self.defaults.string(forKey: "nightscout_api_secret")
        if (apiURL == nil) {
            self.log(str: "Nightscout URL not defined in settings.")
            return false
        }
        if (apiStringSecret == nil) {
            self.log(str: "Nightscout ApiSecret not defined in settings.")
            return false
        }
        let apiSecret = apiStringSecret!.sha1()
        let siteURL = apiURL!  // URL(string: apiURL)!
        let uploadURL = siteURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiSecret, forHTTPHeaderField: "api-secret")
        var success = true
        var error_msg: String = ""
        do {
            
            if let json = json {
                let sendData = try JSONSerialization.data(withJSONObject: json, options: [])
                let task = URLSession.shared.uploadTask(with: request, from: sendData, completionHandler: { (data, response, error) in
                    if let error = error {
                        error_msg = String(describing: error)
                        success = false
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        error_msg = "Response is not HTTPURLResponse"
                        success = false
                        return
                    }
                    
                    if httpResponse.statusCode != 200 {
                        let error = UploadError.httpError(status: httpResponse.statusCode, body:String(data: data!, encoding: String.Encoding.utf8)!)
                        error_msg = "http error: " + String(describing: error)
                        success = false
                        return
                    }
                    
                    guard let data = data else {
                        error_msg = "No data in response"
                        success = false
                        return
                    }
                    
                    do {
                        _ = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions())
                        //return json
                    } catch {
                        //return error
                        error_msg = "json response decoding error"
                        success = false
                        
                    }
                })
                task.resume()
            }
            
        } catch let error {
            error_msg = "Catch: " + String(describing: error)
            success = false
        }
        if (success) {
            self.log(str: "Successfully uploaded data.")
        } else {
            self.log(str: "Upload error: " + error_msg)
        }
        return success
    }
    
}


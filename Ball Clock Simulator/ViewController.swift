//
//  ViewController.swift
//  Ball Clock Simulator
//
//  Created by Peter Nardi on 07/31/16.
//  Copyright (c) 2016-2018, Peter Nardi
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
//  * Neither the name of Ball Clock Simulator nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


import Cocoa
import Carbon
// import Foundation

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    // View Controller Properties ------------------------------------------------
    
    // Pointer to the AppDelegate class to be able to control Save menu state.
    
    let del = NSApplication.shared.delegate as? AppDelegate
    
    let MINBALLS = 27
    let MAXBALLS = 1000
    
    struct SingleRunResult {
        
        var balls : Int, daysWithCam : Int, daysWithoutCam : Int
        var clockTime: String
    }
    
    var arrayOfRuns = [SingleRunResult]()
    var bc = BallClock()
    var srr = SingleRunResult(balls: 0, daysWithCam: 0, daysWithoutCam: 0, clockTime: "")
    var poolSize = 0
    var poolLimit = 0
    var stopButtonPressed = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start with Save and Save As menus disabled.  Save As will stay disabled through the program's run.
        del!.menSave.isEnabled = false
        del!.menSaveAs.isEnabled = false

    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    // Need to wait until the view is ready to appear (all controls in place) before we programmatically
    // set the initial first responder.  Setting the initial first responder is required for the NextKeyView
    // connections to work properly - establishes tab order when tabbing through fields.
    override func viewWillAppear() {
        super.viewWillAppear()
        self.view.window!.initialFirstResponder = self.minBalls
    }
    
    // Implementation of TableView Protocol Methods --------------------------------
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        
        return arrayOfRuns.count
        
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let item = arrayOfRuns[row]
        let result: NSTableCellView = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as! NSTableCellView
        let columnIdentifier: String = tableColumn!.identifier.rawValue
        
        switch columnIdentifier {
        case "balls" :
            result.textField?.stringValue = String(item.balls)
        case "simDaysCam" :
            result.textField?.stringValue = String(item.daysWithCam)
        case "simDaysNoCam" :
            result.textField?.stringValue = String(item.daysWithoutCam)
        case "clockTime" :
            result.textField?.stringValue = item.clockTime
        default :
            result.textField?.stringValue = "error"
        }
        
        return result
        
    }
    
    // Helper functions ----------------------------------------------------------
    
    
    // Round doubles to a selected number of decimal places
    
    func setDecimalPrecision(ofThisNumber n: Double, toThisManyPlaces p: Int) -> Double {
        
        var precisionFactor = 1.0
        
        for _ in 1...p {
            precisionFactor *= 10.0
        }
        return Double(round(n*precisionFactor)/precisionFactor)
    }
    
    // Convert a time (in seconds) to a formatted time string HH:MM:SS.SSSS
    
    func convertToString(thisTimeAsFloat t: Double) -> String {
        
        let PRECISION = 4
        
        var secString,timeString : String
        var hr, min, sec : Double
        var secStringArray = [String]()
        var i = 0
        
        hr = t/60/60
        min = (hr - Double(Int(hr))) * 60
        sec = (min - Double(Int(min))) * 60
        
        if hr < 10 {
            timeString = "0" + Int(hr).description + ":"
        } else {
            timeString = Int(hr).description + ":"
        }
        
        if min < 10 {
            timeString = timeString + "0" + Int(min).description + ":"
        } else {
            timeString = timeString + Int(min).description + ":"
        }
        
        // Set seconds for decimal places of precision
        sec = setDecimalPrecision(ofThisNumber: sec,toThisManyPlaces: PRECISION)
        
        secString = sec.description
        if sec < 10 {
            secString = "0" + secString
        }
        
        secStringArray = secString.components(separatedBy: ".")
        i = secStringArray[1].count
        
        //Pad fractional portion of seconds with zeros if necessary.
        while i < PRECISION {
            secString = secString + "0"
            i += 1
        }
        
        timeString = timeString + secString
        
        return timeString
        
    }
    
    
    // Simulation Looper for specified number of runs --------------------------------
    
    
    func performSimulatedRuns() {
        
        var simRunTimeSingle = 0.0
        var simRunTimeTotal = 0.0
        
        // initialize the poolSize and poolLimit getting values from the main thread.
        // Do it synchronously so you know the poolSize and poolLimit are set properly
        // before simulation runs.
        DispatchQueue.main.sync {
            self.poolSize = self.minBalls.integerValue
            self.poolLimit = self.maxBalls.integerValue
        }
        arrayOfRuns.removeAll(keepingCapacity: false)
        
        // Set up the UI in the Main Thread Queue
        DispatchQueue.main.sync {
            self.progressIndicator.startAnimation(self)
            self.simulationStatus.stringValue = "Running..."
            del!.menSave.isEnabled = false
            self.runButton.isEnabled = false
            self.stopButton.isEnabled = true
            self.resetButton.isEnabled = false
        }
        
        // Execute the required number of sumlation runs
        while (poolSize <= poolLimit) && !stopButtonPressed {
            
            (simRunTimeSingle, srr.daysWithCam, srr.daysWithoutCam) = bc.runSimulation(withNumberOfBalls: poolSize)
            srr.clockTime = convertToString(thisTimeAsFloat: simRunTimeSingle)
            srr.balls = poolSize
            arrayOfRuns.append(srr)
            poolSize += 1
            simRunTimeTotal += simRunTimeSingle
            
            // Update the UI in the Main Thread Queue
            DispatchQueue.main.async {
                self.dataTable.reloadData()
                self.simulationRunTime.stringValue = self.convertToString(thisTimeAsFloat: simRunTimeTotal)
            }
            
        }
        
        //Clean up and reset the UI in the Main Thread Queue
        DispatchQueue.main.sync {
            self.runButton.isEnabled = false
            self.stopButton.isEnabled = false
            self.resetButton.isEnabled = true
            del!.menSave.isEnabled = true
            if self.stopButtonPressed {
                self.simulationStatus.stringValue = "Stopped"
            } else {
                self.simulationStatus.stringValue = "Complete"
            }
            self.progressIndicator.stopAnimation(self)
        }
        
    }
    
    
    // Actions and outlets ------------------------------------------------------
    
    
    @IBOutlet weak var simulationStatus: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var minBalls: NSTextField!
    @IBOutlet weak var maxBalls: NSTextField!
    @IBOutlet weak var runButton: NSButton!
    @IBOutlet weak var stopButton: NSButton!
    @IBOutlet weak var resetButton: NSButton!
    @IBOutlet weak var simulationRunTime: NSTextField!
    @IBOutlet weak var dataTable: NSTableView!
    
    @IBAction func helpButton(_ sender: NSButton) {
        let book = "Ball Clock Simulator Help" as CFString
        let _ = AHGotoPage(book,nil,nil)
    }
    
    @IBAction func saveResults(_ sender: NSButton) {
        
        var tempString = ""
        
        let saveDialog = NSSavePanel()
        saveDialog.title = "Save Ball Clock Data Run"
        saveDialog.nameFieldStringValue = "Ball Clock Run.csv"
        saveDialog.beginSheetModal(for: self.view.window!, completionHandler: { result in
            
            if result != NSApplication.ModalResponse.cancel {
                
                let path = saveDialog.url?.path
                
                if path != nil {
                    
                    for record in self.arrayOfRuns {
                        tempString += String(record.balls) + ","
                        tempString += String(record.daysWithCam) + ","
                        tempString += String(record.daysWithoutCam) + ","
                        tempString += record.clockTime + "\n"
                    }
                    do {
                        try tempString.write(toFile: path!, atomically: true, encoding: String.Encoding.utf8)
                    } catch {
                        let alert = NSAlert.init()
                        alert.messageText = "There was a problem writing to the file."
                        alert.informativeText = "Please try again later"
                        alert.runModal()
                    }
                }
            }
        }) // End of completion handler
    }
    
    @IBAction func runSimulation(_ sender: NSButton) {
        
        // Run the simulation in a background thread
        stopButtonPressed = false
        
        if (minBalls.integerValue < MINBALLS) ||
            (maxBalls.integerValue > MAXBALLS) ||
            (maxBalls.integerValue < minBalls.integerValue) {
            self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "alertSegue"), sender: self)
        } else {
            // Run simulation in a background thread
            DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
                self.performSimulatedRuns()
            }
        }
        // Once compelte, enable the Save menu
        
    }
    
    @IBAction func stopSimulation(_ sender: NSButton) {
        
        simulationStatus.stringValue = "Stopping..."
        stopButtonPressed = true
        sender.isEnabled = false
        del!.menSave.isEnabled = true
        
    }
    
    @IBAction func resetSimulation(_ sender: NSButton) {
        
        stopButton.isEnabled = false
        resetButton.isEnabled = false
        simulationRunTime.stringValue = "00:00:00.0000"
        simulationStatus.stringValue = "Ready"
        arrayOfRuns.removeAll(keepingCapacity: false)
        dataTable.reloadData()
        runButton.isEnabled = true
        del!.menSave.isEnabled = false
        
    }
    
}


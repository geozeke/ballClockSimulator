//
//  BallClock.swift
//  Ball Clock Simulator
//
//  Created by Peter Nardi on 08/06/16.
//  Copyright (c) 2016, Peter Nardi
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
import Foundation

class BallClock: NSObject {
    
    func runSimulation(withNumberOfBalls nBalls: Int) -> (clockTime : Double, daysWithCam : Int, daysWithoutCam : Int) {
        
        let MACHINESIZE = 7
        let MIN1 = 0, MIN5 = 1, HR = 2, PERM = 3, TICK = 4, TOCK = 5, REF = 6
        let MIN1SIZE = 4, MIN5SIZE = 11, HRSIZE = 11
        let BRUTEFORCECYCLES = 720
        
        /*
         
         Each machine contains a reference array, ordered 1 -> n, which shows what the clock should look like in its initial
         condition.  One machine represents the clock with the CAM present, the other represents the clock without the CAM present
         The PERM pool is an array, which starts out being ordered 1 -> n and is "cycled" through the simulated operation of the clock
         until it matches the reference pool (the starting condition).
         
         Initially, the clock is brute-force cycled 12-hrs at a time (720 minutes) until the number of balls in the correct position
         is at least 50% of the total number of balls.  50% ended up being a nice balance between brute-forcing for too long and
         optimizing the permutation vector.  With this optimized permutation vector, each cycling of the clock represents multiple
         12-hr runs, which significantly speeds up the calculations.  The number of 12-hr cycles needed to achieve this 50% permutation
         is called the "unit time" and is used when cycling the pool using the optimized permutation vector.
         
         To cycle the optimized permutation vector, I used a technique I call "tick-tock."  It uses three arrays (PERM, TICK, TOCK).
         PERM is the optimized permutation vector and TICK is the initial ordering of the balls from 0 -> n-1.  Each ball in TICK is
         moved into its new location in TOCK, based on the movement as defined in the permutation vector.  TICK and TOCK are then
         switched (actually just their array indices are switched) and the process is repeated until TICK contains all the balls in the
         original order. The number of days is tracked as tick-tock works through the various permutations.
         
         */
        
        var clockCam = [[Int]]()
        var clockNoCam = [[Int]]()
        var hitTarget = 0.0
        var cycleMin1Cam = false, cycleMin1NoCam = false
        var triggerBallCam = 0, triggerBallNoCam = 0
        var iCam = 0, iNoCam = 0
        var hitCountCam = 0, hitCountNoCam = 0
        var (tickCam,tockCam) = (TICK,TOCK)
        var (tickNoCam,tockNoCam) = (TICK,TOCK)
        var startTime = 0.0, totalRunTime = 0.0
        var unitTimeCam = 0.0, unitTimeNoCam = 0.0
        var daysCam = 0.0, daysNoCam = 0.0
        var hitPercentage : Double
        
        /*
         
         Some clock sizes require special handling.  The results for these clocks are really big (in the hundreds
         of billions or trillions of days).  To calculate the results in a reasonable amount of time, we need to
         ensure that we brute-force the clock sufficiently to get a unitTime big enough to make the tick-tock
         calculations efficient.  Ex: If unitTime only equals 1.5, then counting from 0 to 600 billon by 1.5s,
         will take a very long time.  When we encounter one of these clocks, we need to bump the hitPercentage upward
         slightly, because the baseline percentage (50% of the number of balls) is reached too quickly resulting
         in a small unitTime during tick-tock. The extra time spent brute-forcing is worth it, since it makes the
         tick-tock phase of the calculations much quicker.
         
         I suspect these clock sizes brute-force cycle too quickly because of something special with the clock mechanics
         in relationship to their size.  There are clocks in the 600-700 ball range that brute-force less quickly, but these
         sizes seem special.  It would be interesting to study the mathematics behind this.
         
         */
        
        switch nBalls {
            
        case 649,720,725...726,729,730,732...750 :
            hitPercentage = 0.7
        case 253,477,480,724,727,728 :
            hitPercentage = 0.75
        case 731 :
            hitPercentage = 0.8
        case 733 :
            hitPercentage = 0.83
        case 722,842,869,972,973,974 :
            hitPercentage = 0.6
        case 1000 :
            hitPercentage = 0.63
        case 757,831 :
            hitPercentage = 0.54
        default :
            hitPercentage = 0.5
            
        }
        
        // Establish the hit target to be a percentage of the number of balls when brute-forcing the permutation vector
        
        hitTarget = Double(nBalls) * hitPercentage
        
        // Start the clock
        
        startTime = Date().timeIntervalSinceReferenceDate
        
        // Set up the base arrays for each Machine
        
        for _ in 0..<MACHINESIZE {
            clockCam.append([Int]())
            clockNoCam.append([Int]())
        }
        
        // Create the PERM, TICK, TOCK and REF pools for each machine
        
        for i in 0..<nBalls {
            clockCam[PERM].append(i)
            clockCam[TICK].append(i)
            clockCam[TOCK].append(i)
            clockCam[REF].append(i)
            clockNoCam[PERM].append(i)
            clockNoCam[TICK].append(i)
            clockNoCam[TOCK].append(i)
            clockNoCam[REF].append(i)
        }
        
        // Set up a group and queue to run the CAM and NOCAM scenarios simultaneously in separate threads
        
        let group = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "myConcurrentQueue", qos: .utility, attributes: .concurrent)
        
        // CAM Thread ----------------------------------------------------------------------------------------
        
        concurrentQueue.async(group: group) {
            
            /*
             
             First, build the permutation vector for the condition with the Cam.  Brute force cycle the permutation vector from
             its initial condition until there are at least "hitTarget" matches (balls in the correct position).  The rest of the
             balls in the permutation vector will still be scrambled, but we know that the final alignment of the queue (all
             balls in their proper positions) will be some multiple of this interim step.  We now have an optimized permutation
             vector that can be used to cycle the clock multiple 12-hr periods each time.
             
             */
            
            repeat {
                
                iCam = BRUTEFORCECYCLES
                
                repeat {
                    
                    triggerBallCam = clockCam[PERM][0]
                    clockCam[PERM].remove(at: 0)
                    
                    // ------- Handle one minute rail -------------
                    
                    if (clockCam[MIN1].count == MIN1SIZE) {
                        cycleMin1Cam = true
                        for ball in Array(clockCam[MIN1].reversed()) {
                            clockCam[PERM].append(ball)
                        }
                        clockCam[MIN1].removeAll(keepingCapacity: true)
                    } else {
                        clockCam[MIN1].append(triggerBallCam)
                    }
                    
                    // ------- Handle the 5MIN and HR rails -------------
                    
                    if cycleMin1Cam {
                        if clockCam[MIN5].count == MIN5SIZE {
                            if clockCam[HR].count == HRSIZE {
                                
                                // When the CAM is present, the order of cycling the balls back to the
                                // pool is triggerBall -> HR Rail -> 5MIN Rail
                                
                                clockCam[PERM].append(triggerBallCam)
                                for ball in Array(clockCam[HR].reversed()) {
                                    clockCam[PERM].append(ball)
                                }
                                for ball in Array(clockCam[MIN5].reversed()) {
                                    clockCam[PERM].append(ball)
                                }
                                //-------------------------------------------------------------------------
                                
                                clockCam[HR].removeAll(keepingCapacity: true)
                                clockCam[MIN5].removeAll(keepingCapacity: true)
                            } else {
                                clockCam[HR].append(triggerBallCam)
                                for ball in Array(clockCam[MIN5].reversed()) {
                                    clockCam[PERM].append(ball)
                                }
                                clockCam[MIN5].removeAll(keepingCapacity: true)
                            }
                        } else {
                            clockCam[MIN5].append(triggerBallCam)
                        }
                        cycleMin1Cam = false
                    }
                    
                    iCam -= 1
                    
                } while iCam > 0
                
                unitTimeCam += 0.5 //0.5 days = 12 hours (One complete cycle of the clock).
                hitCountCam = 0
                for iCam in 0..<nBalls {
                    if (clockCam[PERM][iCam] == clockCam[REF][iCam]) {
                        hitCountCam += 1
                    }
                }
                
            } while hitCountCam < Int(hitTarget)
            
            // Use the permutation vector and the "tick tock" strategy to cycle the clock until the balls return to their
            // original order.
            
            repeat {
                
                for iCam in 0..<nBalls {
                    clockCam[tockCam][iCam] = clockCam[tickCam][clockCam[PERM][iCam]]
                }
                daysCam += unitTimeCam
                (tickCam,tockCam) = (tockCam,tickCam)
                
            } while clockCam[tickCam] != clockCam[REF]
            
        }
        
        // No CAM Thread -------------------------------------------------------------------------------------
        
        concurrentQueue.async(group: group) {
            
            /*
             
             Next, build the permutation vector for the condition without the Cam (No Cam).  Brute force cycle the permutation vector from
             its initial condition until there are at least "hitTarget" matches (balls in the correct position).  The rest of the
             balls in the permutation vector will still be scrambled, but we know that the final alignment of the queue (all
             balls in their proper positions) will be some multiple of this interim step.  We now have an optimized permutation
             vector that can be used to cycle the clock multiple 12-hr periods each time.
             
             */
            
            repeat {
                
                iNoCam = BRUTEFORCECYCLES
                
                repeat {
                    
                    triggerBallNoCam = clockNoCam[PERM][0]
                    clockNoCam[PERM].remove(at: 0)
                    
                    // ------- Handle one minute rail -------------
                    
                    if (clockNoCam[MIN1].count == MIN1SIZE) {
                        cycleMin1NoCam = true
                        for ball in Array(clockNoCam[MIN1].reversed()) {
                            clockNoCam[PERM].append(ball)
                        }
                        clockNoCam[MIN1].removeAll(keepingCapacity: true)
                    } else {
                        clockNoCam[MIN1].append(triggerBallNoCam)
                    }
                    
                    // ------- Handle the 5MIN and HR rails -------------
                    
                    if cycleMin1NoCam {
                        if clockNoCam[MIN5].count == MIN5SIZE {
                            if clockNoCam[HR].count == HRSIZE {
                                
                                // When the NO CAM is present, the order of cycling the balls back to the
                                // pool is 5MIN Rail -> triggerBall -> HR Rail
                                
                                for ball in Array(clockNoCam[MIN5].reversed()) {
                                    clockNoCam[PERM].append(ball)
                                }
                                clockNoCam[PERM].append(triggerBallNoCam)
                                for ball in Array(clockNoCam[HR].reversed()) {
                                    clockNoCam[PERM].append(ball)
                                }
                                //----------------------------------------------------------------------------
                                
                                clockNoCam[HR].removeAll(keepingCapacity: true)
                                clockNoCam[MIN5].removeAll(keepingCapacity: true)
                            } else {
                                clockNoCam[HR].append(triggerBallNoCam)
                                for ball in Array(clockNoCam[MIN5].reversed()) {
                                    clockNoCam[PERM].append(ball)
                                }
                                clockNoCam[MIN5].removeAll(keepingCapacity: true)
                            }
                        } else {
                            clockNoCam[MIN5].append(triggerBallNoCam)
                        }
                        cycleMin1NoCam = false
                    }
                    
                    iNoCam -= 1
                    
                } while iNoCam > 0
                
                unitTimeNoCam += 0.5 //0.5 days = 12 hours (One complete cycle of the clock).
                hitCountNoCam = 0
                for iNoCam in 0..<nBalls {
                    if (clockNoCam[PERM][iNoCam] == clockNoCam[REF][iNoCam]) {
                        hitCountNoCam += 1
                    }
                }
                
            } while hitCountNoCam < Int(hitTarget)
            
            // Use the permutation vector and the "tick tock" strategy to cycle the clock until the balls return to their
            // original order.
            
            repeat {
                
                for iNoCam in 0..<nBalls {
                    clockNoCam[tockNoCam][iNoCam] = clockNoCam[tickNoCam][clockNoCam[PERM][iNoCam]]
                }
                daysNoCam += unitTimeNoCam
                (tickNoCam,tockNoCam) = (tockNoCam,tickNoCam)
                
            } while clockNoCam[tickNoCam] != clockNoCam[REF]
            
        }
        
        let _ = group.wait(timeout: .distantFuture)
        totalRunTime = (Date().timeIntervalSinceReferenceDate - startTime)
        
        return(totalRunTime,Int(daysCam),Int(daysNoCam))
        
    }
    
}

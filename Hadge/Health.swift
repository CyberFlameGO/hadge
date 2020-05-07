//
//  Health.swift
//  Hadge
//
//  Created by Thomas Dohmke on 5/2/20.
//  Copyright © 2020 Entire. All rights reserved.
//

import HealthKit
import SwiftCSV

extension Notification.Name {
    static let didReceiveHealthAccess = Notification.Name("didReceiveHealthAccess")
}

class Health {
    static let sharedInstance = Health()

    var year: Int
    var firstOfYear: Date?
    var lastOfYear: Date?
    var healthStore: HKHealthStore?

    static func shared() -> Health {
        return sharedInstance
    }

    init() {
        self.healthStore = HKHealthStore()

        let calendar = Calendar.current
        self.year = calendar.component(.year, from: Date())
        self.firstOfYear = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))

        let firstOfNextYear = Calendar.current.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        self.lastOfYear = Calendar.current.date(byAdding: .day, value: -1, to: firstOfNextYear!)
    }

    func getBiologicalSex() -> HKBiologicalSexObject? {
        var biologicalSex: HKBiologicalSexObject?
        do {
            try biologicalSex = self.healthStore?.biologicalSex()
            return biologicalSex
        } catch {
            return nil
        }
    }

    func seedSampleData() {
        do {
            let path = Bundle.main.path(forResource: "2020", ofType: "csv")
            let csvFile: CSV = try CSV(url: URL(fileURLWithPath: path!))
            try csvFile.enumerateAsDict { row in
                let workout = HKWorkout(activityType: HKWorkoutActivityType(rawValue: UInt(row["type"]!)!)!,
                    start: (row["start_date"]?.toDate())!,
                    end: (row["end_date"]?.toDate())!,
                    duration: TimeInterval(Double(row["duration"]!)!),
                    totalEnergyBurned: HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: Double(row["energy"]!)!),
                    totalDistance: HKQuantity(unit: HKUnit.meter(), doubleValue: Double(row["distance"]!)!),
                    device: HKDevice.local(),
                    metadata: nil)
                self.healthStore!.save(workout) { (_, _) in }
            }
        } catch {}

    }

    func loadActivityData() {
        let calendar = Calendar.current
        var firstOfYear = calendar.dateComponents([ .day, .month, .year], from: self.firstOfYear!)
        var lastOfYear = calendar.dateComponents([ .day, .month, .year], from: self.lastOfYear!)

        // Calendar needs to be non-nil, but isn't auto-populated in dateComponents call
        firstOfYear.calendar = calendar
        lastOfYear.calendar = calendar

        let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: firstOfYear, end: lastOfYear)
        let activityQuery = HKActivitySummaryQuery(predicate: predicate) { (_, summaries, _) in
            guard let summaries = summaries, summaries.count > 0 else { return }
            summaries.reversed().forEach { summary in
                print(summary.description)
            }
        }
        healthStore?.execute(activityQuery)
    }

    func loadWorkouts(completionHandler: @escaping ([HKSample]?) -> Swift.Void) {
        let predicate = HKQuery.predicateForSamples(withStart: Health().firstOfYear, end: Health().lastOfYear, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let sampleQuery = HKSampleQuery(
            sampleType: .workoutType(),
            predicate: predicate,
            limit: 0,
            sortDescriptors: [sortDescriptor]) { (_, workouts, _) in
                completionHandler(workouts)
        }
        healthStore?.execute(sampleQuery)
    }

    func generateContentForWorkouts(workouts: [HKSample]) -> String {
        let header = "uuid,start_date,end_date,type,name,duration,distance,energy\n"
        let content: NSMutableString = NSMutableString.init(string: header)
        workouts.reversed().forEach { workout in
            guard let workout = workout as? HKWorkout else { return }
            let line = "\(workout.uuid),\(workout.startDate),\(workout.endDate),\(workout.workoutActivityType.rawValue),\"\(workout.workoutActivityType.name)\",\(workout.duration),\(workout.totalDistance?.doubleValue(for: HKUnit.meter()) ?? 0),\(workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) ?? 0)\n"
            content.append(line)
        }
        print(content)
        return String.init(content)
    }
}
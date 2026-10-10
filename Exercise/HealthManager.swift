//
//  HealthManager.swift
//  Exercise
//
//  All HealthKit logic lives here. Views observe this class via @Environment.
//

import Foundation
import Observation
import HealthKit

/// One day's step total plus the apps/devices that contributed.
struct DaySteps: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Int
    let sources: [String]   // e.g. ["Garmin Connect", "Apollo's iPhone"]
}

/// The possible states of the step data.
enum StepDataState {
    case notDetermined  // user hasn't been asked for permission yet
    case loading        // query in flight
    case loaded         // data ready (steps may be zero)
    case denied         // user denied HealthKit access
    case unavailable    // HealthKit not available on this device (e.g. iPad)
}

@Observable
final class HealthManager {

    // MARK: - Observable state (views read these)

    var todaySteps: Int = 0
    var todaySources: [String] = []
    var weekSteps: [DaySteps] = []
    var dataState: StepDataState = .notDetermined

    // MARK: - Private

    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)

    // MARK: - Public API

    /// Request HealthKit authorization, then load data. Call once at app launch.
    func requestAuthorizationAndLoad() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            dataState = .unavailable
            return
        }

        do {
            try await store.requestAuthorization(toShare: [], read: [stepType])
        } catch {
            // Only throws for programming errors (e.g. wrong sample types).
            print("[HealthManager] Auth request error: \(error)")
        }

        await refresh()
    }

    /// Reload today's steps and 7-day history. Safe to call from pull-to-refresh
    /// or when the app returns to the foreground.
    func refresh() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            dataState = .unavailable
            return
        }

        // Note: HealthKit never reveals read-permission status via authorizationStatus(for:)
        // (that only reflects share/write permission), so we can't gate on it here. A denied
        // read simply yields empty results from the queries below.
        dataState = .loading

        do {
            // Fire both queries concurrently.
            async let todayResult = fetchTodaySteps()
            async let weekResult  = fetchWeekSteps()
            let (today, week) = try await (todayResult, weekResult)

            todaySteps   = today.steps
            todaySources = today.sources
            weekSteps    = week
            dataState    = .loaded
        } catch {
            print("[HealthManager] Query error: \(error)")
            dataState = .loaded  // show UI anyway; values stay at previous state
        }
    }

    // MARK: - HealthKit queries

    /// Today's cumulative step count plus which sources contributed.
    /// Uses .cumulativeSum so HealthKit de-duplicates overlapping samples
    /// (e.g. Garmin watch and iPhone both recording the same walk).
    private func fetchTodaySteps() async throws -> (steps: Int, sources: [String]) {
        let now        = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate  = HKQuery.predicateForSamples(withStart: startOfDay, end: now)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum, .separateBySource]
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let steps   = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                let sources = result?.sources?.map(\.name).sorted() ?? []
                continuation.resume(returning: (steps, sources))
            }
            self.store.execute(query)
        }
    }

    /// Step totals for each of the last 7 days (today inclusive).
    private func fetchWeekSteps() async throws -> [DaySteps] {
        let calendar    = Calendar.current
        let now         = Date()
        let startOfToday = calendar.startOfDay(for: now)

        guard
            let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday),
            let endDate   = calendar.date(byAdding: .day, value:  1, to: startOfToday)
        else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let interval  = DateComponents(day: 1)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum, .separateBySource],
                anchorDate: startOfToday,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var days: [DaySteps] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                    let steps   = Int(stats.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    let sources = stats.sources?.map(\.name).sorted() ?? []
                    days.append(DaySteps(date: stats.startDate, steps: steps, sources: sources))
                }
                continuation.resume(returning: days)
            }

            self.store.execute(query)
        }
    }
}

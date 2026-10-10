//
//  StepBarChart.swift
//  Exercise
//

import SwiftUI
import Charts

/// A bar chart showing step counts for the last 7 days.
/// Today's bar is rendered in the accent color; past days are dimmed.
struct StepBarChart: View {
    let days: [DaySteps]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 Days")
                .font(.headline)

            Chart(days) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Steps", day.steps)
                )
                .foregroundStyle(
                    Calendar.current.isDateInToday(day.date)
                        ? Color.accentColor
                        : Color.accentColor.opacity(0.35)
                )
                .cornerRadius(6)
                .annotation(position: .top) {
                    Text(day.steps, format: .number)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            .chartXAxis {
                // One label per day, formatted as a narrow weekday letter (M, T, W …)
                AxisMarks(values: .stride(by: .day)) {
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis {
                AxisMarks(preset: .automatic) { _ in
                    AxisGridLine()
                }
            }
            // Leave headroom above the tallest bar so its annotation isn't clipped.
            .chartYScale(domain: 0...max(1, (days.map(\.steps).max() ?? 0) * 6 / 5))
            .frame(height: 180)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let sample = (0..<7).compactMap { offset -> DaySteps? in
        guard let date = calendar.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
        return DaySteps(date: date, steps: Int.random(in: 3000...12000), sources: ["Garmin Connect"])
    }
    return StepBarChart(days: sample)
        .padding()
}

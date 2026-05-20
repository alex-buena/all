import SwiftUI

struct GraphDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct NetWorthGraph: View {
    let dataPoints: [GraphDataPoint]
    var lineColor: Color = .green
    @Binding var selectedIndex: Int?

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)
            ZStack {
                if points.count >= 2 {
                    // Dimmed right side (full graph, dimmed)
                    if let selectedIdx = selectedIndex, selectedIdx < points.count {
                        let rightPoints = Array(points.suffix(from: selectedIdx))
                        if rightPoints.count >= 2 {
                            areaPath(points: rightPoints, height: proxy.size.height)
                                .fill(
                                    LinearGradient(
                                        colors: [lineColor.opacity(0.15), lineColor.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            linePath(points: rightPoints)
                                .stroke(
                                    lineColor.opacity(0.4),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                                )
                        }

                        // Full color left side (up to selected point)
                        let leftPoints = Array(points.prefix(through: selectedIdx))
                        if leftPoints.count >= 2 {
                            areaPath(points: leftPoints, height: proxy.size.height)
                                .fill(
                                    LinearGradient(
                                        colors: [lineColor.opacity(0.35), lineColor.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            linePath(points: leftPoints)
                                .stroke(
                                    lineColor,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                                )
                        }

                        // Selection indicator
                        let selectedPoint = points[selectedIdx]
                        Circle()
                            .fill(lineColor)
                            .frame(width: 10, height: 10)
                            .position(selectedPoint)

                        // Vertical line at selection
                        Path { path in
                            path.move(to: CGPoint(x: selectedPoint.x, y: 0))
                            path.addLine(to: CGPoint(x: selectedPoint.x, y: proxy.size.height))
                        }
                        .stroke(lineColor.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                        // Date tooltip
                        dateTooltip(for: selectedIdx, at: selectedPoint, in: proxy.size)
                    } else {
                        // No selection - show full graph
                        areaPath(points: points, height: proxy.size.height)
                            .fill(
                                LinearGradient(
                                    colors: [lineColor.opacity(0.35), lineColor.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        linePath(points: points)
                            .stroke(
                                lineColor,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                            )
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let index = indexForLocation(value.location.x, in: proxy.size)
                        if index != selectedIndex {
                            selectedIndex = index
                            // Haptic feedback on selection change
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        // Clear selection when finger is lifted
                        selectedIndex = nil
                    }
            )
        }
    }

    private func indexForLocation(_ x: CGFloat, in size: CGSize) -> Int {
        guard dataPoints.count >= 2 else { return 0 }
        let stepX = size.width / CGFloat(dataPoints.count - 1)
        let index = Int(round(x / stepX))
        return max(0, min(dataPoints.count - 1, index))
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        let values = dataPoints.map { $0.value }
        guard values.count >= 2 else { return [] }
        guard let minValue = values.min(), let maxValue = values.max() else { return [] }
        let range = max(maxValue - minValue, 0.0001)
        let stepX = size.width / CGFloat(values.count - 1)

        return values.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let normalized = (value - minValue) / range
            let y = size.height * (1 - CGFloat(normalized))
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midX = (previous.x + current.x) / 2
            path.addCurve(
                to: current,
                control1: CGPoint(x: midX, y: previous.y),
                control2: CGPoint(x: midX, y: current.y)
            )
        }
        return path
    }

    private func areaPath(points: [CGPoint], height: CGFloat) -> Path {
        var path = linePath(points: points)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: height))
        path.addLine(to: CGPoint(x: first.x, y: height))
        path.closeSubpath()
        return path
    }

    private func dateTooltip(for index: Int, at point: CGPoint, in size: CGSize) -> some View {
        let dataPoint = dataPoints[index]
        let dateText = Self.tooltipDateFormatter.string(from: dataPoint.date)

        // Calculate tooltip position - always at top of dotted line
        let tooltipWidth: CGFloat = 90
        let tooltipHeight: CGFloat = 28

        // Keep tooltip within horizontal bounds
        let xPosition = min(max(point.x, tooltipWidth / 2 + 4), size.width - tooltipWidth / 2 - 4)
        // Position at the top of the graph
        let yPosition = tooltipHeight / 2 + 4

        return Text(dateText)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            )
            .position(x: xPosition, y: yPosition)
    }

    private static let tooltipDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}

// Legacy initializer for backward compatibility
extension NetWorthGraph {
    init(values: [Double], lineColor: Color = .green) {
        let points = values.enumerated().map { index, value in
            GraphDataPoint(
                date: Calendar.current.date(byAdding: .day, value: -values.count + index + 1, to: Date()) ?? Date(),
                value: value
            )
        }
        self.dataPoints = points
        self.lineColor = lineColor
        self._selectedIndex = .constant(nil)
    }
}

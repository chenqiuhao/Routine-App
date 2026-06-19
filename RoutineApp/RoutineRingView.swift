import SwiftUI

struct RoutineRingView: View {
    @Environment(\.colorScheme) private var colorScheme

    let routines: [Routine]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let metrics = DialMetrics(size: size)
            let palette = DialPalette(colorScheme: colorScheme)
            let labelPlacements = makeLabelPlacements(for: routines, metrics: metrics)

            ZStack {
                Circle()
                    .fill(palette.face)
                    .frame(width: metrics.innerFillDiameter, height: metrics.innerFillDiameter)

                Circle()
                    .stroke(
                        palette.track,
                        style: StrokeStyle(lineWidth: metrics.ringWidth, lineCap: .butt)
                    )
                    .frame(width: metrics.ringMidDiameter, height: metrics.ringMidDiameter)

                ForEach(routines) { routine in
                    RoutineArcShape(
                        startMinutes: routine.startMinutes,
                        endMinutes: routine.endMinutes,
                        innerRatio: metrics.innerRingRatio,
                        outerRatio: metrics.outerRingRatio,
                        gapDegrees: metrics.segmentGapDegrees
                    )
                    .fill(routine.color.swiftUIColor)
                    .opacity(0.98)
                }

                InnerLabelGuideLayer(placements: labelPlacements, metrics: metrics, palette: palette)

                TickLayer(metrics: metrics, palette: palette)

                ForEach(0..<24, id: \.self) { hour in
                    let angle = angleFor(minutes: hour * 60)
                    let point = pointOnCircle(radius: metrics.hourLabelRadius, angleDegrees: angle)

                    Text("\(hour)")
                        .font(.system(size: metrics.hourFontSize, weight: hour % 6 == 0 ? .black : .semibold))
                        .monospacedDigit()
                        .foregroundStyle(hour % 6 == 0 ? palette.primaryText : palette.secondaryText)
                        .position(x: metrics.center + point.x, y: metrics.center + point.y)
                }

                ForEach(labelPlacements) { placement in
                    ArcRoutineNameLabel(placement: placement, metrics: metrics, palette: palette)
                }

                CurrentTimeHand(metrics: metrics, palette: palette)
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("二十四小时日程环")
    }
}

private struct DialMetrics {
    let size: CGFloat

    var center: CGFloat { size / 2 }
    var outerRingRatio: CGFloat { 0.49 }
    var innerRingRatio: CGFloat { 0.425 }
    var outerRingRadius: CGFloat { size * outerRingRatio }
    var innerRingRadius: CGFloat { size * innerRingRatio }
    var ringWidth: CGFloat { outerRingRadius - innerRingRadius }
    var ringMidDiameter: CGFloat { (outerRingRadius - ringWidth / 2) * 2 }
    var innerFillDiameter: CGFloat { (innerRingRadius - size * 0.012) * 2 }
    var hourLabelRadius: CGFloat { size * 0.350 }
    var labelRadius: CGFloat { size * 0.308 }
    var sideInnerLabelRadius: CGFloat { size * 0.266 }
    var outsideLabelRadius: CGFloat { size * 0.532 }
    var hourFontSize: CGFloat { max(15, size * 0.034) }
    var labelMinFontSize: CGFloat { max(12.5, size * 0.031) }
    var labelMaxFontSize: CGFloat { max(19, size * 0.050) }
    var outsideLabelMaxFontSize: CGFloat { max(17, size * 0.044) }
    var majorTickLength: CGFloat { size * 0.024 }
    var minorTickLength: CGFloat { size * 0.012 }
    var tickGap: CGFloat { size * 0.016 }
    var segmentGapDegrees: Double { size < 360 ? 0.85 : 0.58 }
}

private struct DialPalette {
    let face: Color
    let track: Color
    let tick: Color
    let primaryText: Color
    let secondaryText: Color
    let hand: Color

    init(colorScheme: ColorScheme) {
        switch colorScheme {
        case .dark:
            face = Color(red: 0.07, green: 0.12, blue: 0.14)
            track = Color.white.opacity(0.18)
            tick = Color.white.opacity(0.70)
            primaryText = Color.white.opacity(0.92)
            secondaryText = Color.white.opacity(0.56)
            hand = Color.white.opacity(0.92)
        case .light:
            face = Color(red: 0.84, green: 0.95, blue: 0.97)
            track = Color(red: 0.74, green: 0.79, blue: 0.80).opacity(0.62)
            tick = Color.black.opacity(0.58)
            primaryText = Color.black.opacity(0.78)
            secondaryText = Color.black.opacity(0.48)
            hand = Color.black
        @unknown default:
            face = Color(red: 0.84, green: 0.95, blue: 0.97)
            track = Color(red: 0.74, green: 0.79, blue: 0.80).opacity(0.62)
            tick = Color.black.opacity(0.58)
            primaryText = Color.black.opacity(0.78)
            secondaryText = Color.black.opacity(0.48)
            hand = Color.black
        }
    }
}

private struct RoutineLabelPlacement: Identifiable {
    let id: UUID
    let lines: [String]
    let centerAngle: Double
    let radius: CGFloat
    let fontSize: CGFloat
    let angleStep: Double
    let radialStep: CGFloat
    let reversed: Bool
}

private struct RoutineLabelInfo {
    let routine: Routine
    let lines: [String]
    let midpointAngle: Double
    let normalizedAngle: Double
    let durationDegrees: Double
    let longestLineCount: Int
}

private struct ArcRoutineNameLabel: View {
    let placement: RoutineLabelPlacement
    let metrics: DialMetrics
    let palette: DialPalette

    var body: some View {
        ZStack {
            ForEach(placement.lines.indices, id: \.self) { lineIndex in
                let line = Array(placement.lines[lineIndex])
                let lineOffset = CGFloat(lineIndex) - CGFloat(placement.lines.count - 1) / 2
                let lineRadius = placement.radius + lineOffset * placement.radialStep

                ForEach(line.indices, id: \.self) { index in
                    let positionIndex = placement.reversed ? line.count - 1 - index : index
                    let centeredIndex = Double(positionIndex) - Double(line.count - 1) / 2
                    let angle = placement.centerAngle + centeredIndex * placement.angleStep
                    let point = pointOnCircle(radius: lineRadius, angleDegrees: angle)

                    Text(String(line[index]))
                        .font(.system(size: placement.fontSize, weight: .black, design: .default))
                        .foregroundStyle(palette.primaryText)
                        .rotationEffect(.degrees(uprightTangentRotation(for: angle)))
                        .position(x: metrics.center + point.x, y: metrics.center + point.y)
                }
            }
        }
        .frame(width: metrics.size, height: metrics.size)
        .allowsHitTesting(false)
    }
}

private struct InnerLabelGuideLayer: View {
    let placements: [RoutineLabelPlacement]
    let metrics: DialMetrics
    let palette: DialPalette

    var body: some View {
        Canvas { context, _ in
            let center = CGPoint(x: metrics.center, y: metrics.center)

            for placement in placements where placement.needsGuideLine(metrics: metrics) {
                let lineReach = max(
                    placement.fontSize * 1.1,
                    placement.fontSize * CGFloat(max(placement.lines.count, 1)) * 0.58
                )
                let startRadius = placement.radius + lineReach + metrics.size * 0.008
                let endRadius = metrics.innerRingRadius + metrics.ringWidth * 0.16

                guard startRadius < endRadius else { continue }

                let start = absolutePoint(center: center, radius: startRadius, angleDegrees: placement.centerAngle)
                let end = absolutePoint(center: center, radius: endRadius, angleDegrees: placement.centerAngle)
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)

                context.stroke(
                    path,
                    with: .color(palette.primaryText.opacity(0.22)),
                    style: StrokeStyle(lineWidth: max(0.8, metrics.size * 0.0015), lineCap: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct RoutineArcShape: Shape {
    var startMinutes: Int
    var endMinutes: Int
    var innerRatio: CGFloat
    var outerRatio: CGFloat
    var gapDegrees: Double

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = side * outerRatio
        let innerRadius = side * innerRatio
        let rawDuration = endMinutes.normalizedDayMinute - startMinutes.normalizedDayMinute
        let duration = max(2, rawDuration > 0 ? rawDuration : rawDuration + minutesPerDay)
        let gap = min(gapDegrees, Double(duration) / Double(minutesPerDay) * 180)
        let startAngleBase = angleFor(minutes: startMinutes)
        let endAngleBase = startAngleBase + Double(duration) / Double(minutesPerDay) * 360
        let startAngle = startAngleBase + gap
        let endAngle = endAngleBase - gap

        var path = Path()
        let samples = max(8, Int(Double(duration) / 12.0))

        for index in 0...samples {
            let progress = Double(index) / Double(samples)
            let angle = startAngle + (endAngle - startAngle) * progress
            let point = absolutePoint(center: center, radius: outerRadius, angleDegrees: angle)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        for index in stride(from: samples, through: 0, by: -1) {
            let progress = Double(index) / Double(samples)
            let angle = startAngle + (endAngle - startAngle) * progress
            let point = absolutePoint(center: center, radius: innerRadius, angleDegrees: angle)
            path.addLine(to: point)
        }

        path.closeSubpath()
        return path
    }
}

private extension RoutineLabelPlacement {
    func needsGuideLine(metrics: DialMetrics) -> Bool {
        radius < metrics.labelRadius - metrics.size * 0.01
    }
}

private struct TickLayer: View {
    let metrics: DialMetrics
    let palette: DialPalette

    var body: some View {
        Canvas { context, _ in
            for tick in 0..<48 {
                let isHour = tick.isMultiple(of: 2)
                let minute = tick * 30
                let angle = angleFor(minutes: minute)
                let length = isHour ? metrics.majorTickLength : metrics.minorTickLength
                let lineWidth = isHour ? max(3.2, metrics.size * 0.0046) : max(1.8, metrics.size * 0.0024)
                let endRadius = metrics.innerRingRadius - metrics.tickGap
                let start = absolutePoint(
                    center: CGPoint(x: metrics.center, y: metrics.center),
                    radius: endRadius - length,
                    angleDegrees: angle
                )
                let end = absolutePoint(
                    center: CGPoint(x: metrics.center, y: metrics.center),
                    radius: endRadius,
                    angleDegrees: angle
                )

                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(
                    path,
                    with: .color(palette.tick.opacity(isHour ? 1.0 : 0.70)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
            }
        }
    }
}

private struct CurrentTimeHand: View {
    let metrics: DialMetrics
    let palette: DialPalette

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let components = Calendar.current.dateComponents([.hour, .minute], from: timeline.date)
            let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            let angle = angleFor(minutes: minutes)
            let center = CGPoint(x: metrics.center, y: metrics.center)
            let start = absolutePoint(
                center: center,
                radius: metrics.innerRingRadius - metrics.majorTickLength * 1.6,
                angleDegrees: angle
            )
            let end = absolutePoint(
                center: center,
                radius: metrics.outerRingRadius + metrics.size * 0.026,
                angleDegrees: angle
            )

            Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            .stroke(palette.hand, style: StrokeStyle(lineWidth: max(6, metrics.size * 0.01), lineCap: .round))
        }
        .allowsHitTesting(false)
    }
}

private func makeLabelPlacements(for routines: [Routine], metrics: DialMetrics) -> [RoutineLabelPlacement] {
    let infos = routines.map { routine in
        let midpointAngle = angleFor(minutes: routine.midpointMinutes)
        let lines = wrappedLabelLines(for: routine.name)
        return RoutineLabelInfo(
            routine: routine,
            lines: lines,
            midpointAngle: midpointAngle,
            normalizedAngle: normalizedDialDegrees(midpointAngle),
            durationDegrees: Double(routine.durationMinutes) / Double(minutesPerDay) * 360,
            longestLineCount: max(lines.map(\.count).max() ?? 1, 1)
        )
    }

    let sortedInfos = infos.sorted { $0.normalizedAngle < $1.normalizedAngle }
    var placedLabels: [PlacedLabel] = []

    return sortedInfos.map { info in
        let placement = bestPlacement(for: info, metrics: metrics, placedLabels: placedLabels)
        placedLabels.append(placedLabel(for: info, placement: placement, metrics: metrics))
        return placement
    }
}

private struct LabelCandidate {
    let radius: CGFloat
    let outside: Bool
    let looseness: Double
    let fontScale: CGFloat
}

private struct PlacedLabel {
    let bounds: CGRect
    let priority: Double
}

private func bestPlacement(
    for info: RoutineLabelInfo,
    metrics: DialMetrics,
    placedLabels: [PlacedLabel]
) -> RoutineLabelPlacement {
    let candidates = labelCandidates(for: info, metrics: metrics)

    let evaluated = candidates.map { makePlacement(for: info, metrics: metrics, candidate: $0) }
    let nonOverlapping = evaluated.first { placement in
        let label = placedLabel(for: info, placement: placement, metrics: metrics)
        return !placedLabels.contains { overlaps(label, $0) }
    }

    return nonOverlapping ?? evaluated.min { first, second in
        placementCollisionScore(placedLabel(for: info, placement: first, metrics: metrics), placedLabels) <
            placementCollisionScore(placedLabel(for: info, placement: second, metrics: metrics), placedLabels)
    } ?? evaluated[0]
}

private func labelCandidates(for info: RoutineLabelInfo, metrics: DialMetrics) -> [LabelCandidate] {
    if isSideAngle(info.midpointAngle) {
        return [
            LabelCandidate(radius: metrics.labelRadius, outside: false, looseness: 1.05, fontScale: 1.00),
            LabelCandidate(radius: metrics.sideInnerLabelRadius, outside: false, looseness: 0.98, fontScale: 0.92),
            LabelCandidate(radius: metrics.labelRadius, outside: false, looseness: 0.92, fontScale: 0.82),
            LabelCandidate(radius: metrics.sideInnerLabelRadius, outside: false, looseness: 0.88, fontScale: 0.74),
            LabelCandidate(radius: metrics.labelRadius, outside: false, looseness: 0.82, fontScale: 0.66),
            LabelCandidate(radius: metrics.sideInnerLabelRadius, outside: false, looseness: 0.78, fontScale: 0.58)
        ]
    }

    return [
        LabelCandidate(radius: metrics.labelRadius, outside: false, looseness: 1.10, fontScale: 1.00),
        LabelCandidate(radius: metrics.outsideLabelRadius, outside: true, looseness: 1.65, fontScale: 0.96),
        LabelCandidate(radius: metrics.labelRadius, outside: false, looseness: 0.96, fontScale: 0.84),
        LabelCandidate(radius: metrics.outsideLabelRadius, outside: true, looseness: 1.35, fontScale: 0.78)
    ]
}

private func makePlacement(
    for info: RoutineLabelInfo,
    metrics: DialMetrics,
    candidate: LabelCandidate
) -> RoutineLabelPlacement {
    let maxFontSize = candidate.outside ? metrics.outsideLabelMaxFontSize : metrics.labelMaxFontSize
    let availableDegrees = candidate.outside
        ? min(88, max(info.durationDegrees * candidate.looseness, Double(info.longestLineCount) * 7.2))
        : min(78, max(info.durationDegrees * candidate.looseness, Double(info.longestLineCount) * 6.4))
    let availableArc = candidate.radius * CGFloat(availableDegrees * .pi / 180)
    let fittedFontSize = availableArc / CGFloat(info.longestLineCount) * 1.04
    let minFontSize = max(8.5, metrics.labelMinFontSize * min(candidate.fontScale, 0.90))
    let fontSize = min(maxFontSize * candidate.fontScale, max(minFontSize, fittedFontSize))
    let naturalStep = Double(fontSize * 0.96 / candidate.radius) * 180 / .pi
    let maxStep = info.longestLineCount > 1 ? availableDegrees / Double(info.longestLineCount - 1) : 0
    let angleStep = info.longestLineCount > 1 ? min(naturalStep, maxStep) : 0

    return RoutineLabelPlacement(
        id: info.routine.id,
        lines: info.lines,
        centerAngle: info.midpointAngle,
        radius: candidate.radius,
        fontSize: fontSize,
        angleStep: angleStep,
        radialStep: fontSize * 1.10,
        reversed: shouldReverseTextOrder(at: info.midpointAngle)
    )
}

private func placedLabel(
    for info: RoutineLabelInfo,
    placement: RoutineLabelPlacement,
    metrics: DialMetrics
) -> PlacedLabel {
    PlacedLabel(
        bounds: labelBounds(for: placement, metrics: metrics).insetBy(dx: -4, dy: -4),
        priority: placement.radius == metrics.labelRadius ? 0 : 1
    )
}

private func placementCollisionScore(_ label: PlacedLabel, _ placedLabels: [PlacedLabel]) -> Double {
    placedLabels.reduce(label.priority * 20) { score, placed in
        guard label.bounds.intersects(placed.bounds) else { return score }
        return score + Double(intersectionArea(label.bounds, placed.bounds))
    }
}

private func overlaps(_ first: PlacedLabel, _ second: PlacedLabel) -> Bool {
    first.bounds.intersects(second.bounds)
}

private func labelBounds(for placement: RoutineLabelPlacement, metrics: DialMetrics) -> CGRect {
    var union = CGRect.null

    for lineIndex in placement.lines.indices {
        let line = placement.lines[lineIndex]
        let lineOffset = CGFloat(lineIndex) - CGFloat(placement.lines.count - 1) / 2
        let lineRadius = placement.radius + lineOffset * placement.radialStep
        let center = pointOnCircle(radius: lineRadius, angleDegrees: placement.centerAngle)
        let charCount = max(line.count, 1)
        let arcWidth = CGFloat(max(charCount - 1, 0)) *
            CGFloat(placement.angleStep * .pi / 180) *
            lineRadius + placement.fontSize * 0.95
        let lineHeight = placement.fontSize * 1.20
        let lineBounds = rotatedLineBounds(
            center: CGPoint(x: metrics.center + center.x, y: metrics.center + center.y),
            angle: placement.centerAngle,
            width: arcWidth,
            height: lineHeight
        )

        union = union.union(lineBounds)
    }

    return union
}

private func rotatedLineBounds(center: CGPoint, angle: Double, width: CGFloat, height: CGFloat) -> CGRect {
    let radians = angle * .pi / 180
    let tangent = CGVector(dx: -sin(radians), dy: cos(radians))
    let normal = CGVector(dx: cos(radians), dy: sin(radians))
    let halfWidth = width / 2
    let halfHeight = height / 2
    let corners = [
        point(center, tangent, normal, halfWidth, halfHeight),
        point(center, tangent, normal, halfWidth, -halfHeight),
        point(center, tangent, normal, -halfWidth, halfHeight),
        point(center, tangent, normal, -halfWidth, -halfHeight)
    ]

    let minX = corners.map(\.x).min() ?? center.x
    let maxX = corners.map(\.x).max() ?? center.x
    let minY = corners.map(\.y).min() ?? center.y
    let maxY = corners.map(\.y).max() ?? center.y

    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}

private func point(
    _ center: CGPoint,
    _ tangent: CGVector,
    _ normal: CGVector,
    _ tangentOffset: CGFloat,
    _ normalOffset: CGFloat
) -> CGPoint {
    CGPoint(
        x: center.x + tangent.dx * tangentOffset + normal.dx * normalOffset,
        y: center.y + tangent.dy * tangentOffset + normal.dy * normalOffset
    )
}

private func intersectionArea(_ first: CGRect, _ second: CGRect) -> CGFloat {
    let intersection = first.intersection(second)
    guard !intersection.isNull else { return 0 }
    return intersection.width * intersection.height
}

private func wrappedLabelLines(for name: String) -> [String] {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let source = trimmed.isEmpty ? "日程" : trimmed
    let paragraphs = source.split(whereSeparator: { $0.isNewline }).map(String.init)
    let lines = paragraphs.flatMap { wrapLabelLine($0, maxCharacters: 7) }
    return Array(lines.prefix(3))
}

private func wrapLabelLine(_ line: String, maxCharacters: Int) -> [String] {
    guard line.count > maxCharacters else {
        return [line]
    }

    let words = line.split(separator: " ").map(String.init)
    guard words.count > 1 else {
        return chunked(line, maxCharacters: maxCharacters)
    }

    var lines: [String] = []
    var current = ""

    for word in words {
        if word.count > maxCharacters {
            if !current.isEmpty {
                lines.append(current)
                current = ""
            }
            lines.append(contentsOf: chunked(word, maxCharacters: maxCharacters))
        } else if current.isEmpty {
            current = word
        } else if current.count + 1 + word.count <= maxCharacters {
            current += " " + word
        } else {
            lines.append(current)
            current = word
        }
    }

    if !current.isEmpty {
        lines.append(current)
    }

    return lines
}

private func chunked(_ text: String, maxCharacters: Int) -> [String] {
    var chunks: [String] = []
    var current = ""

    for character in text {
        current.append(character)
        if current.count >= maxCharacters {
            chunks.append(current)
            current = ""
        }
    }

    if !current.isEmpty {
        chunks.append(current)
    }

    return chunks
}

private func angleFor(minutes: Int) -> Double {
    -90 + Double(minutes.normalizedDayMinute) / Double(minutesPerDay) * 360
}

private func normalizedDialDegrees(_ angle: Double) -> Double {
    let value = angle.truncatingRemainder(dividingBy: 360)
    return value >= 0 ? value : value + 360
}

private func circularDegreesBetween(_ first: Double, _ second: Double) -> Double {
    let difference = abs(first - second).truncatingRemainder(dividingBy: 360)
    return min(difference, 360 - difference)
}

private func isSideAngle(_ angle: Double) -> Bool {
    let radians = angle * .pi / 180
    return abs(cos(radians)) > 0.48
}

private func shouldReverseTextOrder(at angle: Double) -> Bool {
    let radians = angle * .pi / 180
    return -sin(radians) < 0
}

private func pointOnCircle(radius: CGFloat, angleDegrees: Double) -> CGPoint {
    let radians = angleDegrees * .pi / 180
    return CGPoint(x: cos(radians) * radius, y: sin(radians) * radius)
}

private func absolutePoint(center: CGPoint, radius: CGFloat, angleDegrees: Double) -> CGPoint {
    let point = pointOnCircle(radius: radius, angleDegrees: angleDegrees)
    return CGPoint(x: center.x + point.x, y: center.y + point.y)
}

private func uprightTangentRotation(for angle: Double) -> Double {
    var rotation = angle + 90
    while rotation > 90 {
        rotation -= 180
    }
    while rotation < -90 {
        rotation += 180
    }
    return rotation
}

#Preview {
    RoutineRingView(
        routines: [
            Routine(name: "睡觉", startMinutes: 22 * 60, endMinutes: 6 * 60, color: RoutineColor.defaultColor(at: 9)),
            Routine(name: "测试", startMinutes: 1 * 60, endMinutes: 5 * 60, color: RoutineColor.defaultColor(at: 9)),
            Routine(name: "跑步", startMinutes: 6 * 60, endMinutes: 8 * 60, color: RoutineColor.defaultColor(at: 1)),
            Routine(name: "吃饭", startMinutes: 8 * 60, endMinutes: 9 * 60, color: RoutineColor.defaultColor(at: 2)),
            Routine(name: "新日程", startMinutes: 8 * 60 + 30, endMinutes: 10 * 60, color: RoutineColor.defaultColor(at: 4)),
            Routine(name: "工作", startMinutes: 12 * 60, endMinutes: 16 * 60, color: RoutineColor.defaultColor(at: 6))
        ]
    )
    .padding()
    .background(Color(.systemBackground))
}

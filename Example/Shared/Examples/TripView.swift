import Prefire
import SwiftUI

enum TripStatus {
    case onTime
    case delayed(minutes: Int, departure: String)
    case loading
}

struct TripView: View {
    let status: TripStatus

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                BoardingPassCard(status: status)
                if case let .delayed(_, departure) = status {
                    DelayBanner(departure: departure)
                }
                checklist
                walletButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
            .redacted(reason: isLoading ? .placeholder : [])
        }
        .background(Color(.systemGroupedBackground))
    }

    private var isLoading: Bool {
        if case .loading = status { return true }
        return false
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Friday, 14 November")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Your trip")
                    .font(.largeTitle.bold())
            }
            Spacer()
            Text("AK")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.orange.gradient))
        }
    }

    private var checklist: some View {
        VStack(spacing: 0) {
            ChecklistRow(icon: "checkmark.circle.fill", tint: .green, title: "Checked in", detail: "Seat 14A, window")
            Divider().padding(.leading, 52)
            ChecklistRow(icon: "suitcase.rolling.fill", tint: .blue, title: "Bag drop closes", detail: "08:40, desks 21–24")
            Divider().padding(.leading, 52)
            ChecklistRow(icon: "figure.walk", tint: .orange, title: "Security", detail: "About 15 min wait")
        }
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var walletButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "wallet.pass.fill")
            Text("Add to Apple Wallet")
        }
        .font(.headline)
        .foregroundStyle(Color(.systemBackground))
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(Capsule().fill(Color.primary))
    }
}

private struct BoardingPassCard: View {
    let status: TripStatus

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("Northwind Air", systemImage: "airplane")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    StatusPill(status: status)
                }
                HStack(alignment: .firstTextBaseline) {
                    airport(code: "LIS", city: "Lisbon", time: "09:40", alignment: .leading)
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "airplane")
                            .font(.title3)
                        Text("3h 45m")
                            .font(.caption.weight(.medium))
                            .opacity(0.8)
                    }
                    Spacer()
                    airport(code: "AMS", city: "Amsterdam", time: "13:25", alignment: .trailing)
                }
            }
            .padding(20)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.98, green: 0.42, blue: 0.21), Color(red: 0.72, green: 0.13, blue: 0.29)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            HStack {
                detail("Flight", "NW 214")
                Spacer()
                detail("Gate", "B12")
                Spacer()
                detail("Seat", "14A")
                Spacer()
                detail("Boarding", boardingTime)
            }
            .padding(20)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }

    private var boardingTime: String {
        if case .delayed = status { return "09:50" }
        return "09:05"
    }

    private func airport(code: String, city: String, time: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(code)
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text(city)
                .font(.footnote.weight(.medium))
                .opacity(0.85)
            Text(time)
                .font(.title3.weight(.semibold).monospacedDigit())
                .padding(.top, 6)
        }
    }

    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
    }
}

private struct StatusPill: View {
    let status: TripStatus

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.white.opacity(0.22)))
    }

    private var title: String {
        switch status {
        case .onTime: "On time"
        case let .delayed(minutes, _): "Delayed \(minutes) min"
        case .loading: "Updating"
        }
    }
}

private struct DelayBanner: View {
    let departure: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("New departure \(departure)")
                    .font(.headline)
                Text("Boarding moved to 09:50. We'll let you know if the gate changes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.orange.opacity(0.14)))
    }
}

private struct ChecklistRow: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

extension PreviewModel.UserStory {
    static let trip = "Trip"
}

extension PreviewModel.State {
    static let delayed = "delayed"
}

#Preview("Trip") {
    TripView(status: .onTime)
        .previewUserStory(.trip)
}

#Preview("Trip delayed") {
    TripView(status: .delayed(minutes: 45, departure: "10:25"))
        .previewUserStory(.trip)
        .previewState(.delayed)
}

#Preview("Trip loading") {
    TripView(status: .loading)
        .previewUserStory(.trip)
        .previewState(.loading)
}

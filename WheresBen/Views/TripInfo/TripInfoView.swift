import SwiftUI

struct TripInfoView: View {
    @EnvironmentObject var tripData: TripDataService

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Schedule Overview
                scheduleSection

                // Accommodation
                accommodationSection

                // Contact Ben
                contactSection

                // Emergency Contacts
                emergencySection
            }
            .padding()
        }
        .background(Color.cozyBackground)
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Schedule Overview")

            VStack(spacing: 0) {
                ScheduleRow(date: "Tue 12 May", event: "Depart Sydney", icon: "airplane.departure")
                ScheduleRow(date: "Wed 13 May", event: "Arrive Prague", icon: "airplane.arrival")
                ScheduleRow(date: "Thu 14 - Sat 16 May", event: "EAPC Conference", icon: "building.2", isHighlighted: true)
                // TODO: Add presentation slot when known
                ScheduleRow(date: "Sat 16 May", event: "Depart Prague", icon: "airplane.departure")
                ScheduleRow(date: "Mon 18 May", event: "Home! 🎉", icon: "house.fill", isLast: true)
            }
            .background(Color.cozyCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Accommodation Section

    private var accommodationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Accommodation")

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Image(systemName: "bed.double.fill")
                        .foregroundColor(.cozyAccent)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tripData.config.hotelName ?? "STAGES HOTEL Prague")
                            .font(.cozyHeadline)
                            .foregroundColor(.cozyText)

                        if let address = tripData.config.hotelAddress {
                            Link(destination: URL(string: "maps://?q=\(address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
                                HStack {
                                    Text(address)
                                        .font(.cozyCaption)
                                        .foregroundColor(.cozyAccent)
                                    Image(systemName: "map")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Check-in")
                            .font(.cozyCaption)
                            .foregroundColor(.cozyTextSecondary)
                        Text("Wed 13 May, 3:00pm")
                            .font(.cozyBody)
                            .foregroundColor(.cozyText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Check-out")
                            .font(.cozyCaption)
                            .foregroundColor(.cozyTextSecondary)
                        Text("Sat 16 May, 12:00pm")
                            .font(.cozyBody)
                            .foregroundColor(.cozyText)
                    }
                }
            }
            .padding()
            .background(Color.cozyCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Contact Section

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Contact Ben")

            VStack(spacing: 12) {
                // WhatsApp call button
                if let phone = tripData.config.contactPhone {
                    Link(destination: URL(string: "https://wa.me/\(phone.replacingOccurrences(of: "+", with: ""))")!) {
                        HStack {
                            Image(systemName: "phone.fill")
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text("Call on WhatsApp")
                                    .font(.cozyHeadline)
                                Text(phone)
                                    .font(.cozyCaption)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                // Regular phone
                if let phone = tripData.config.contactPhone {
                    Link(destination: URL(string: "tel:\(phone)")!) {
                        HStack {
                            Image(systemName: "phone")
                            Text("Call Mobile")
                                .font(.cozyBody)
                            Spacer()
                            Text(phone)
                                .font(.cozyCaption)
                                .foregroundColor(.cozyTextSecondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.cozyTextSecondary)
                        }
                        .foregroundColor(.cozyText)
                        .padding()
                        .background(Color.cozyCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Emergency Section

    private var emergencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Emergency Contacts")

            VStack(spacing: 0) {
                EmergencyContactRow(
                    title: "Australian Consulate Prague",
                    phone: tripData.config.consulatePhone ?? "+420 257 022 100"
                )

                Divider().padding(.leading, 44)

                EmergencyContactRow(
                    title: "Travel Insurance",
                    subtitle: tripData.config.insurancePolicy,
                    phone: tripData.config.insurancePhone ?? "Not set"
                )

                if let emergency = tripData.config.emergencyContact {
                    Divider().padding(.leading, 44)

                    EmergencyContactRow(
                        title: "Emergency Contact",
                        phone: emergency
                    )
                }
            }
            .background(Color.cozyCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.cozyCaption)
            .foregroundColor(.cozyTextSecondary)
            .textCase(.uppercase)
            .padding(.horizontal, 4)
    }
}

// MARK: - Schedule Row

struct ScheduleRow: View {
    let date: String
    let event: String
    let icon: String
    var isHighlighted: Bool = false
    var isLast: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Timeline dot and line
            VStack(spacing: 0) {
                Circle()
                    .fill(isHighlighted ? Color.cozyAccent : Color.cozyTextSecondary.opacity(0.3))
                    .frame(width: 10, height: 10)

                if !isLast {
                    Rectangle()
                        .fill(Color.cozyTextSecondary.opacity(0.2))
                        .frame(width: 2)
                }
            }
            .frame(width: 10)

            Image(systemName: icon)
                .foregroundColor(isHighlighted ? .cozyAccent : .cozyTextSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(date)
                    .font(.cozyCaption)
                    .foregroundColor(.cozyTextSecondary)
                Text(event)
                    .font(.cozyBody)
                    .foregroundColor(isHighlighted ? .cozyAccent : .cozyText)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Emergency Contact Row

struct EmergencyContactRow: View {
    let title: String
    var subtitle: String? = nil
    let phone: String

    var body: some View {
        HStack {
            Image(systemName: "phone.fill")
                .foregroundColor(.cozyAccent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.cozyBody)
                    .foregroundColor(.cozyText)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.cozyCaption)
                        .foregroundColor(.cozyTextSecondary)
                }
            }

            Spacer()

            Link(destination: URL(string: "tel:\(phone)")!) {
                Text(phone)
                    .font(.cozyCaption)
                    .foregroundColor(.cozyAccent)
            }
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        TripInfoView()
            .navigationTitle("Trip Info")
    }
    .environmentObject(TripDataService.shared)
}

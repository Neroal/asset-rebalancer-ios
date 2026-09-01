import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var portfolioVM: PortfolioViewModel
    @EnvironmentObject var lang: LanguageViewModel
    @State private var showSaveSuccess = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    // MARK: - Allocation Templates

    private var templateButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.allocationTemplates)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(AllocationTemplate.allCases) { template in
                    let isSelected = template.matches(portfolioVM.targetAllocation)
                    Button {
                        portfolioVM.targetAllocation = template.allocation
                        Task { await portfolioVM.saveTarget() }
                    } label: {
                        VStack(spacing: 2) {
                            Text(lang.localized(template.displayName))
                                .font(.subheadline)
                                .fontWeight(isSelected ? .semibold : .regular)
                            Text("\(Int(template.allocation.stock))/\(Int(template.allocation.bond))/\(Int(template.allocation.cash))")
                                .font(.caption2)
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                        .foregroundColor(isSelected ? .white : .primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Account
                Section(lang.account) {
                    if let user = authVM.user {
                        HStack {
                            if let photoURL = user.photoURL {
                                AsyncImage(url: photoURL) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 44, height: 44)
                                    .foregroundColor(.gray)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName ?? "")
                                    .font(.headline)
                                Text(user.email ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Target Allocation
                Section(lang.targetAllocationSetting) {
                    templateButtons

                    AllocationSlider(
                        label: lang.stocks,
                        value: $portfolioVM.targetAllocation.stock,
                        color: .blue
                    )
                    AllocationSlider(
                        label: lang.bonds,
                        value: $portfolioVM.targetAllocation.bond,
                        color: .green
                    )
                    AllocationSlider(
                        label: lang.cash,
                        value: $portfolioVM.targetAllocation.cash,
                        color: .orange
                    )

                    let total = portfolioVM.targetAllocation.stock +
                                portfolioVM.targetAllocation.bond +
                                portfolioVM.targetAllocation.cash
                    HStack {
                        Text(lang.total)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(Rebalancer.formatPercentage(total))
                            .foregroundColor(abs(total - 100) < 0.01 ? .green : .red)
                            .fontWeight(.semibold)
                    }

                    Button(lang.save) {
                        Task {
                            await portfolioVM.saveTarget()
                            if portfolioVM.errorMessage == nil {
                                showSaveSuccess = true
                            }
                        }
                    }
                    .disabled(!portfolioVM.targetAllocation.isValid)
                }

                // Deviation Threshold
                Section(lang.deviationThreshold) {
                    VStack {
                        HStack {
                            Text(Rebalancer.formatPercentage(portfolioVM.deviationThreshold))
                                .font(.headline)
                            Spacer()
                        }
                        Slider(value: $portfolioVM.deviationThreshold, in: 1...20, step: 0.5) {
                            Text(lang.deviationThreshold)
                        }
                        .onChange(of: portfolioVM.deviationThreshold) { _, _ in
                            Task { await portfolioVM.saveThreshold() }
                        }
                    }
                }

                // Language
                Section(lang.language_) {
                    Picker(lang.language_, selection: $lang.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                }

                // Sign Out & Delete Account
                Section {
                    Button(role: .destructive) {
                        authVM.signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Text(lang.signOut)
                            Spacer()
                        }
                    }

                    Button(role: .destructive) {
                        showDeleteAccountConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            if isDeletingAccount {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(lang.deleteAccountTitle)
                            Spacer()
                        }
                    }
                    .disabled(isDeletingAccount)
                    .alert(lang.deleteAccountConfirmTitle, isPresented: $showDeleteAccountConfirmation) {
                        Button(lang.cancel, role: .cancel) {}
                        Button(lang.delete, role: .destructive) {
                            isDeletingAccount = true
                            Task {
                                await authVM.deleteAccount()
                                isDeletingAccount = false
                                if let error = authVM.errorMessage {
                                    deleteErrorMessage = error
                                    showDeleteError = true
                                    authVM.errorMessage = nil
                                }
                            }
                        }
                    } message: {
                        Text(lang.deleteAccountConfirmMessage)
                    }
                }
            }
            .navigationTitle(lang.tabSettings)
            .alert(lang.saveSuccessTitle, isPresented: $showSaveSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(lang.saveSuccessMessage)
            }
            .alert(lang.errorOccurred, isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteErrorMessage)
            }
        }
    }
}

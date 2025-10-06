import SwiftUI
import Speech

struct VoiceExpenseEntryView: View {
    @EnvironmentObject private var budgetViewModel: BudgetViewModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isRecording = false
    @State private var transcript: String = ""
    @State private var amountString: String = ""
    @State private var vendor: String = ""
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var categoryDetected = false
    @State private var isSaving = false
    @State private var showPermissionAlert = false
    @State private var authorizationChecked = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                transcriptSection
                formSection
                Spacer(minLength: 12)
                saveButton
            }
            .padding()
            .navigationTitle("Voice Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            Task {
                await speechRecognizer.requestAuthorization()
                authorizationChecked = true
                if speechRecognizer.authorizationStatus != .authorized {
                    showPermissionAlert = true
                }
            }
        }
        .onDisappear {
            speechRecognizer.stopTranscribing()
        }
        .onReceive(speechRecognizer.$transcript) { newValue in
            transcript = newValue
            updateFromTranscript(newValue)
        }
        .alert("Microphone Access Needed", isPresented: $showPermissionAlert, actions: {
            Button("OK", role: .cancel) { dismiss() }
        }, message: {
            Text("Enable microphone and speech recognition access in Settings to log expenses with your voice.")
        })
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcript")
                    .font(.headline)
                Spacer()
                recordButton
            }

            ScrollView {
                Text(transcript.isEmpty ? placeholderText : transcript)
                    .font(.body)
                    .foregroundColor(transcript.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxHeight: 160)
        }
    }

    private var formSection: some View {
        Form {
            Section(header: Text("Amount")) {
                TextField("0.00", text: $amountString)
                    .keyboardType(.decimalPad)
            }

            Section(header: Text("Vendor")) {
                TextField("Vendor name", text: $vendor)
                    .textInputAutocapitalization(.words)
            }

            Section(header: Text("Category")) {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ExpenseCategory.allCases) { category in
                        Text(settings.displayName(for: category)).tag(category)
                    }
                }
                .pickerStyle(.menu)
                if categoryDetected {
                    Text("Detected from speech")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxHeight: 320)
        .scrollDisabled(true)
    }

    private var saveButton: some View {
        Button(action: { Task { await saveExpense() } }) {
            HStack {
                if isSaving { ProgressView() }
                Text("Save Expense")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canSave ? Color.accentColor : Color.accentColor.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(!canSave || isSaving)
    }

    private var recordButton: some View {
        Button(action: toggleRecording) {
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(12)
                .background(isRecording ? Color.red : Color.accentColor)
                .clipShape(Circle())
        }
        .disabled(!authorizationChecked || speechRecognizer.authorizationStatus != .authorized)
        .accessibilityLabel(isRecording ? Text("Stop Recording") : Text("Start Recording"))
    }

    private func toggleRecording() {
        guard speechRecognizer.authorizationStatus == .authorized else {
            showPermissionAlert = true
            return
        }
        if isRecording {
            speechRecognizer.stopTranscribing()
            isRecording = false
        } else {
            do {
                try speechRecognizer.startTranscribing()
                isRecording = true
            } catch {
                showPermissionAlert = true
            }
        }
    }

    private func updateFromTranscript(_ text: String) {
        let parsed = VoiceExpenseParser.parse(text, settings: settings)
        if let amount = parsed.amount, amountString.isEmpty {
            amountString = NSDecimalNumber(decimal: amount).stringValue
        }
        if let vendorName = parsed.vendor, vendor.isEmpty {
            vendor = vendorName
        }
        if let category = parsed.category {
            selectedCategory = category
            categoryDetected = true
        }
    }

    private var canSave: Bool {
        guard let _ = Decimal(string: amountString.filter { !$0.isWhitespace }) else { return false }
        return !vendor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveExpense() async {
        guard let amount = Decimal(string: amountString.filter { !$0.isWhitespace }) else { return }
        isSaving = true
        await budgetViewModel.addExpense(vendor: vendor.trimmingCharacters(in: .whitespacesAndNewlines), amount: amount, category: selectedCategory)
        await MainActor.run {
            isSaving = false
            dismiss()
        }
    }

    private var placeholderText: String {
        "Tap the microphone and say something like: $12.80 at Starbucks - Food"
    }
}

struct VoiceExpenseEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = AppSettings.shared
        let store = DailyLimitStore.shared
        VoiceExpenseEntryView()
            .environmentObject(BudgetViewModel(dailyLimitStore: store, settings: settings))
            .environmentObject(settings)
    }
}

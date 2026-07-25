import SwiftUI
import UIKit

@MainActor
struct TrainingView: View {
    @Environment(\.dismiss) private var dismiss
    let plan: TrainingPlan
    @StateObject private var viewModel: TrainingViewModel
    @State private var showActionSelect = false
    @State private var showCancelAlert = false
    @State private var showCompleteAlert = false
    @State private var showPlanUpdateAlert = false
    @State private var showActionHistory = false
    @State private var selectedActionForHistory: (id: Int, name: String)?
    @State private var showCompletionError = false
    @StateObject private var keyboardManager = CustomKeyboardManager()

    init(plan: TrainingPlan, viewModel: TrainingViewModel? = nil) {
        self.plan = plan
        _viewModel = StateObject(wrappedValue: viewModel ?? TrainingViewModel())
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TrainingSessionContent(
                editingActions: Binding(get: { viewModel.editingActions }, set: viewModel.updateActions),
                completedSets: Binding(get: { viewModel.completedSets }, set: viewModel.updateCompletedSets),
                setNotes: Binding(get: { viewModel.setNotes }, set: viewModel.updateSetNotes),
                setRestTimers: viewModel.setRestTimers,
                volumeText: viewModel.volumeText,
                elapsedTimeText: viewModel.elapsedTimeText,
                planName: viewModel.planName,
                onAdd: { showActionSelect = true },
                onDelete: viewModel.deleteAction,
                onSetCompleted: viewModel.toggleSetCompletion,
                onRestTimerTapped: viewModel.showRestTimer,
                onShowActionHistory: { id, name in
                    selectedActionForHistory = (id, name)
                    showActionHistory = true
                },
                keyboardManager: keyboardManager
            )
            if keyboardManager.isShowing {
                CustomNumberKeyboard(
                    value: $keyboardManager.currentValue,
                    isShowing: $keyboardManager.isShowing,
                    step: keyboardManager.step,
                    maxValue: keyboardManager.maxValue,
                    isInteger: keyboardManager.isInteger,
                    keyboardManager: keyboardManager
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.clear)
        .navigationTitle("training.navigation.active")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            TrainingToolbar(
                isCompleting: viewModel.isCompleting,
                onCancel: { showCancelAlert = true },
                onComplete: { showCompleteAlert = true }
            )
        }
        .sheet(isPresented: $showActionSelect) { PlanActionSelectView(onActionSelected: addAction) }
        .sheet(isPresented: $showActionHistory) {
            if let selection = selectedActionForHistory {
                ActionHistoryView(actionId: selection.id, actionName: selection.name, viewModel: ActionHistoryViewModel(repository: SQLiteActionHistoryRepository()))
            }
        }
        .overlay(restTimerOverlay)
        .alert("training.alert.cancel.title", isPresented: $showCancelAlert) {
            Button("training.action.resume", role: .cancel) {}
            Button("training.action.cancelWorkout", role: .destructive) { viewModel.cancelTraining(); dismiss() }
        } message: { Text("training.alert.cancel.message") }
        .alert("training.alert.complete.title", isPresented: $showCompleteAlert) {
            Button("training.action.cancel", role: .cancel) {}
            Button("training.action.confirm") { viewModel.hasPlanChanges() ? (showPlanUpdateAlert = true) : saveHistoryOnly() }
        } message: { Text("training.alert.complete.message") }
        .alert("training.alert.updatePlan.title", isPresented: $showPlanUpdateAlert) {
            Button("training.action.doNotUpdate", role: .cancel, action: saveHistoryOnly)
            Button("training.action.update") { saveHistoryAndUpdatePlan() }
        } message: { Text("training.alert.updatePlan.message") }
        .alert("training.alert.error.title", isPresented: $showCompletionError) {
            if viewModel.canRetryPlanUpdate { Button("training.action.retryUpdate", action: retryCompletion) }
            Button("training.action.confirm", role: .cancel) {}
        } message: { Text(viewModel.completionError ?? String(localized: "training.error.unknown")) }
        .onAppear { viewModel.startIfNeeded(plan: plan) }
    }

    private func addAction(_ action: ActionInfo) {
        var actions = viewModel.editingActions
        actions.append(MutableTrainingAction(id: action.id, name: action.name, imageUrl: action.imageUrl, sets: [MutableTrainingSet(id: Int.random(in: 100000...999999), weight: 10, reps: 12)], restTime: 60, recordBilateral: false))
        viewModel.updateActions(actions)
    }

    private func saveHistoryOnly() {
        Task { if await viewModel.saveHistoryOnly() { dismiss() } else { showCompletionError = true } }
    }

    private func saveHistoryAndUpdatePlan() {
        Task { if await viewModel.saveHistoryAndUpdatePlan() { dismiss() } else { showCompletionError = true } }
    }

    private func retryCompletion() {
        Task { if await viewModel.retryCompletion() { dismiss() } else { showCompletionError = true } }
    }

    @ViewBuilder private var restTimerOverlay: some View {
        if viewModel.showRestTimer {
            RestTimerOverlay(restTime: .constant(viewModel.currentRestTime), isRunning: !viewModel.isRestTimerPaused, onPause: viewModel.toggleRestTimer, onReset: viewModel.resetRestTimer, onSkip: viewModel.skipRestTimer, onClose: viewModel.closeRestTimer, onAddTime: { viewModel.addRestTime(10) }, onSubtractTime: { viewModel.subtractRestTime(10) })
        }
    }
}

private struct TrainingToolbar: ToolbarContent {
    let isCompleting: Bool
    let onCancel: () -> Void
    let onComplete: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("training.action.cancelWorkout", action: onCancel)
                .foregroundStyle(.red)
                .accessibilityHint("training.accessibility.cancelWorkoutHint")
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: onComplete) {
                if isCompleting {
                    ProgressView().accessibilityHidden(true)
                } else {
                    Text("training.action.complete")
                }
            }
            .disabled(isCompleting)
            .accessibilityLabel("training.action.complete")
            .accessibilityValue(isCompleting ? Text("training.state.processing") : Text(""))
        }
    }
}

private struct TrainingSessionContent: View {
    @Environment(\.designTokens) private var tokens
    @Binding var editingActions: [MutableTrainingAction]
    @Binding var completedSets: Set<String>
    @Binding var setNotes: [String: String]
    let setRestTimers: [String: Int]
    let volumeText: String
    let elapsedTimeText: String
    let planName: String
    let onAdd: () -> Void
    let onDelete: (MutableTrainingAction) -> Void
    let onSetCompleted: (String, Int) -> Void
    let onRestTimerTapped: (String, Int) -> Void
    let onShowActionHistory: (Int, String) -> Void
    let keyboardManager: CustomKeyboardManager

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.medium) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                    Text(planName).font(DesignTokens.Typography.pageTitle).foregroundStyle(tokens.contentPrimary)
                    HStack {
                        Label(volumeText, systemImage: "scalemass").accessibilityLabel("training.accessibility.volume").accessibilityValue(volumeText)
                        Spacer()
                        Label(elapsedTimeText, systemImage: "timer").accessibilityLabel("training.accessibility.elapsed").accessibilityValue(elapsedTimeText)
                    }
                    .font(DesignTokens.Typography.supporting)
                    .foregroundStyle(tokens.contentSecondary)
                }
                .padding(DesignTokens.Spacing.large)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.action, style: .continuous))

                ForEach(editingActions, id: \.id) { action in
                    TrainingActionCard(action: binding(for: action), completedSets: $completedSets, setNotes: $setNotes, setRestTimers: setRestTimers, onDelete: { onDelete(action) }, onSetCompleted: onSetCompleted, onRestTimerTapped: onRestTimerTapped, onShowActionHistory: onShowActionHistory, canDelete: editingActions.count > 1, keyboardManager: keyboardManager)
                }
                SemanticActionButton(title: "training.action.addAction", loadingTitle: "training.action.addAction", style: .secondary, isEnabled: true, isLoading: false, action: onAdd)
            }
            .padding(DesignTokens.Spacing.large)
        }
        .background(tokens.canvas)
    }

    private func binding(for action: MutableTrainingAction) -> Binding<MutableTrainingAction> {
        Binding(get: { editingActions.first(where: { $0.id == action.id }) ?? action }, set: { updated in
            if let index = editingActions.firstIndex(where: { $0.id == updated.id }) { editingActions[index] = updated }
        })
    }
}

private struct TrainingActionCard: View {
    @Environment(\.designTokens) private var tokens
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var action: MutableTrainingAction
    @Binding var completedSets: Set<String>
    @Binding var setNotes: [String: String]
    let setRestTimers: [String: Int]
    let onDelete: () -> Void
    let onSetCompleted: (String, Int) -> Void
    let onRestTimerTapped: (String, Int) -> Void
    let onShowActionHistory: (Int, String) -> Void
    let canDelete: Bool
    let keyboardManager: CustomKeyboardManager
    @State private var expanded = true
    @State private var showDeleteAlert = false
    @State private var showRestTimerSettings = false
    @State private var restMinutes = 1
    @State private var restSeconds = 0

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.medium) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(tokens.primary).frame(width: 44, height: 44).background(tokens.controlSurface).clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                    Text(action.name).font(DesignTokens.Typography.action).foregroundStyle(tokens.contentPrimary).fixedSize(horizontal: false, vertical: true)
                    Text(trainingFormat("training.detail.setCount", action.sets.count)).font(DesignTokens.Typography.supporting).foregroundStyle(tokens.contentSecondary)
                }
                Spacer()
                Menu {
                    Button("training.action.configureRest") {
                        restMinutes = action.restTime / 60
                        restSeconds = action.restTime % 60
                        showRestTimerSettings = true
                    }
                    Button("training.action.deleteAction", role: .destructive) { showDeleteAlert = true }.disabled(!canDelete)
                } label: {
                    Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("training.accessibility.actionMenu")
            }
            Toggle("training.action.recordBilateral", isOn: $action.recordBilateral)
                .tint(tokens.primary)
                .onChange(of: action.recordBilateral) { _, bilateral in
                    for index in action.sets.indices {
                        if bilateral { action.sets[index].weight = 0 } else { action.sets[index].leftWeight = 0; action.sets[index].rightWeight = 0 }
                    }
                }
            if expanded {
                ForEach(Array(action.sets.enumerated()), id: \.element.id) { index, set in
                    SetEditor(index: index, set: set, action: $action, completedSets: $completedSets, setNotes: $setNotes, restTimeRemaining: setRestTimers["\(action.id)_\(set.id)"], onSetCompleted: onSetCompleted, onRestTimerTapped: onRestTimerTapped, keyboardManager: keyboardManager)
                }
                HStack {
                    Button("training.action.addSet") { action.sets.append(MutableTrainingSet(id: Int.random(in: 100000...999999), weight: 10, reps: 12)) }
                    Spacer()
                    Button("training.action.history") { onShowActionHistory(action.id, action.name) }
                }
                .font(DesignTokens.Typography.action).foregroundStyle(tokens.primary)
            }
        }
        .padding(DesignTokens.Spacing.large)
        .background(tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.action, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: DesignTokens.Radius.action, style: .continuous).stroke(tokens.border, lineWidth: DesignTokens.Metric.borderWidth) }
        .alert("training.alert.deleteAction.title", isPresented: $showDeleteAlert) {
            Button("training.action.cancel", role: .cancel) {}
            Button("training.action.delete", role: .destructive, action: onDelete)
        } message: { Text("training.alert.deleteAction.message") }
        .sheet(isPresented: $showRestTimerSettings) {
            NavigationStack {
                Form {
                    Section("training.rest.configure") {
                        Stepper(trainingFormat("training.rest.minutes", restMinutes), value: $restMinutes, in: 0...10)
                        Stepper(trainingFormat("training.rest.secondsOnly", restSeconds), value: $restSeconds, in: 0...59)
                    }
                }
                .navigationTitle("training.rest.configure")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("training.action.cancel") { showRestTimerSettings = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("training.action.confirm") {
                            action.restTime = restMinutes * 60 + restSeconds
                            showRestTimerSettings = false
                        }
                    }
                }
            }
        }
    }
}

private struct SetEditor: View {
    @Environment(\.designTokens) private var tokens
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let index: Int
    let set: MutableTrainingSet
    @Binding var action: MutableTrainingAction
    @Binding var completedSets: Set<String>
    @Binding var setNotes: [String: String]
    let restTimeRemaining: Int?
    let onSetCompleted: (String, Int) -> Void
    let onRestTimerTapped: (String, Int) -> Void
    let keyboardManager: CustomKeyboardManager

    @State private var showNoteInput = false

    private var setID: String { "\(action.id)_\(set.id)" }
    private var isCompleted: Bool { completedSets.contains(setID) }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack {
                Text(trainingFormat("training.set.number", index + 1)).font(DesignTokens.Typography.action).foregroundStyle(tokens.contentPrimary)
                Spacer()
                Button(action: { onSetCompleted(setID, action.restTime) }) {
                    Label(isCompleted ? "training.state.completed" : "training.action.markComplete", systemImage: isCompleted ? "checkmark.circle.fill" : "circle")
                }
                .foregroundStyle(isCompleted ? tokens.primary : tokens.contentSecondary)
                .accessibilityValue(isCompleted ? Text("training.state.completed") : Text("training.state.incomplete"))
                Menu {
                    Button(showNoteInput ? "training.action.hideNote" : "training.action.addNote") { showNoteInput.toggle() }
                    if action.sets.count > 1 {
                        Button("training.action.deleteSet", role: .destructive) {
                            action.sets.removeAll { $0.id == set.id }
                            completedSets.remove(setID)
                            setNotes.removeValue(forKey: setID)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("training.accessibility.setMenu")
            }
            if action.recordBilateral {
                HStack { numericButton("training.field.leftWeight", value: set.leftWeight, inputID: "left_\(setID)", update: { action.sets[index].leftWeight = $0 }); numericButton("training.field.rightWeight", value: set.rightWeight, inputID: "right_\(setID)", update: { action.sets[index].rightWeight = $0 }) }
            } else {
                numericButton("training.field.weight", value: set.weight, inputID: "weight_\(setID)", update: { action.sets[index].weight = $0 })
            }
            HStack {
                numericButton("training.field.repetitions", value: Double(set.reps), inputID: "reps_\(setID)", isInteger: true, update: { action.sets[index].reps = Int($0) })
                Button(action: { onRestTimerTapped(setID, action.restTime) }) {
                    Label(restTimeRemaining.map(formatRestTime) ?? trainingFormat("training.rest.seconds", action.restTime), systemImage: "timer")
                }
                .accessibilityLabel("training.accessibility.restTimer")
                .accessibilityValue(restTimeRemaining.map(formatRestTime) ?? trainingFormat("training.rest.seconds", action.restTime))
            }
            if showNoteInput {
                TextField("training.field.note", text: Binding(get: { setNotes[setID] ?? "" }, set: { setNotes[setID] = $0 }))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("training.field.note")
            }
        }
        .padding(DesignTokens.Spacing.medium)
        .background(tokens.controlSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous))
    }

    private func numericButton(_ label: LocalizedStringKey, value: Double, inputID: String, isInteger: Bool = false, update: @escaping (Double) -> Void) -> some View {
        Button {
            keyboardManager.showKeyboard(inputId: inputID, initialValue: value, isInteger: isInteger, onValueChanged: update)
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                Text(label).font(DesignTokens.Typography.feedback).foregroundStyle(tokens.contentSecondary)
                Text(isInteger ? String(Int(value)) : String(format: "%.1f", value)).font(DesignTokens.Typography.action).foregroundStyle(tokens.contentPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metric.minimumTapSize, alignment: .leading)
            .padding(.horizontal, DesignTokens.Spacing.small)
            .background(tokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous))
        }
        .accessibilityLabel(label)
        .accessibilityValue(isInteger ? String(Int(value)) : String(format: "%.1f", value))
        .accessibilityHint("training.accessibility.editValueHint")
    }
}

struct RestTimerOverlay: View {
    @Environment(\.designTokens) private var tokens
    @Binding var restTime: Int
    let isRunning: Bool
    let onPause: () -> Void
    let onReset: () -> Void
    let onSkip: () -> Void
    let onClose: () -> Void
    let onAddTime: () -> Void
    let onSubtractTime: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: DesignTokens.Spacing.large) {
                HStack { Spacer(); Button(action: onClose) { Image(systemName: "xmark.circle.fill").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("training.action.closeRest") }
                Text(formatRestTime(restTime)).font(.system(.largeTitle, design: .rounded).bold()).monospacedDigit().foregroundStyle(tokens.contentPrimary).accessibilityLabel("training.accessibility.restTimer").accessibilityValue(formatRestTime(restTime))
                Text(isRunning ? "training.state.running" : "training.state.paused").font(DesignTokens.Typography.supporting).foregroundStyle(tokens.contentSecondary)
                HStack(spacing: DesignTokens.Spacing.small) {
                    timerButton("minus", label: "training.action.subtractTenSeconds", action: onSubtractTime)
                    timerButton(isRunning ? "pause.fill" : "play.fill", label: isRunning ? "training.action.pause" : "training.action.resume", action: onPause)
                    timerButton("plus", label: "training.action.addTenSeconds", action: onAddTime)
                }
                HStack(spacing: DesignTokens.Spacing.small) {
                    SemanticActionButton(title: "training.action.reset", loadingTitle: "training.action.reset", style: .secondary, isEnabled: true, isLoading: false, action: onReset)
                    SemanticActionButton(title: "training.action.finishRest", loadingTitle: "training.action.finishRest", style: .primary, isEnabled: true, isLoading: false, action: onSkip)
                }
            }
            .padding(DesignTokens.Spacing.xLarge)
            .frame(maxWidth: 500)
            .background(tokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.action, style: .continuous))
            .padding(DesignTokens.Spacing.large)
        }
        .accessibilityElement(children: .contain)
    }

    private func timerButton(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(minWidth: 44, minHeight: 44).background(tokens.controlSurface).clipShape(Circle()) }
            .foregroundStyle(tokens.primary).accessibilityLabel(label)
    }
}

private func trainingFormat(_ key: String, _ value: Int) -> String {
    String(format: NSLocalizedString(key, comment: ""), value)
}

private func formatRestTime(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

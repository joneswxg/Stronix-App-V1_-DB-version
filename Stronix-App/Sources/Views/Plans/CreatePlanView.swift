import SwiftUI
import UIKit
import Combine

struct PlanAction: Identifiable, PlanFormAction {
    let id: Int
    let actionId: Int
    let name: String
    let imageUrl: String
    let nameEn: String
    let bodyPartId: Int
    let equipmentId: Int
    let targetMuscleIds: [Int]
    var sets: [PlanSet]
    var restTime = 60
    var notes = ""
    var isExpanded = false
    var isLeftRightMode = false

    typealias SetValue = PlanSet

    var formNote: String {
        get { notes }
        set { notes = newValue }
    }

    var recordsBilateral: Bool {
        get { isLeftRightMode }
        set { isLeftRightMode = newValue }
    }
}

struct PlanSet: Identifiable, PlanFormSet {
    let id = UUID()
    var weight = 0.0
    var leftWeight = 0.0
    var rightWeight = 0.0
    var reps = 0
    var notes = ""
    var isCompleted = false
    var hasNotes = false
}

enum PlanWeightUnit: String, CaseIterable {
    case kg = "kg"
    case lbs = "lbs"
}

struct CreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: AppTheme
    @StateObject private var viewModel: CreatePlanViewModel
    @State private var showActionSelect = false
    @State private var weightUnit: PlanWeightUnit = .kg
    @State private var selectedTargetMuscleId = 0
    @StateObject private var keyboardManager = CustomKeyboardManager()
    private let onSaveSucceeded: () async -> Void

    init(viewModel: CreatePlanViewModel, onSaveSucceeded: @escaping () async -> Void = {}) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSaveSucceeded = onSaveSucceeded
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        PlanFormNameEditor(
                            name: $viewModel.planName,
                            description: $viewModel.planNote,
                            isDescriptionVisible: $viewModel.showPlanNote,
                            style: .optionalMenu,
                            isDisabled: viewModel.isSaving,
                            dismissNumericKeyboard: keyboardManager.cancelKeyboard
                        )

                        if !viewModel.selectedActions.isEmpty {
                            PlanFormActionList(
                                actions: $viewModel.selectedActions,
                                weightUnit: weightUnit.rawValue,
                                allowsUnitToggle: true,
                                notesConfiguration: PlanFormSetNotesConfiguration(
                                    hasNotes: { $0.hasNotes },
                                    toggleNotes: { set in
                                        set.hasNotes.toggle()
                                        if !set.hasNotes { set.notes = "" }
                                    },
                                    note: { $0.notes },
                                    updateNote: { set, note in set.notes = note }
                                ),
                                usesCircularImage: true,
                                isDisabled: viewModel.isSaving,
                                keyboardManager: keyboardManager,
                                makeSet: PlanSet.init,
                                onDelete: deleteAction,
                                onToggleUnit: toggleWeightUnit,
                                actionDetail: actionDetail
                            )
                        }

                        addActionButton
                        Spacer(minLength: 50)
                        if keyboardManager.isShowing { Spacer().frame(height: 280) }
                    }
                    .padding(.top, 20)
                }
                .background(theme.background)
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    if keyboardManager.isShowing { keyboardManager.cancelKeyboard() }
                }

                if keyboardManager.isShowing { keyboard }
            }
            .navigationTitle("创建计划")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消", action: dismiss.callAsFunction).disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    PlanFormSaveButton(
                        isSaving: viewModel.isSaving,
                        isEnabled: !viewModel.planName.isEmpty && !viewModel.selectedActions.isEmpty
                    ) {
                        Task { await viewModel.save() }
                    }
                }
            }
            .alert("错误", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )) {
                Button("确定", action: viewModel.dismissError)
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("成功", isPresented: Binding(
                get: { viewModel.savedPlanID != nil },
                set: { if !$0 { viewModel.consumeSavedPlanID() } }
            )) {
                Button("确定") {
                    viewModel.consumeSavedPlanID()
                    dismiss()
                }
            } message: {
                Text("计划保存成功！")
            }
        }
        .task(id: viewModel.savedPlanID) {
            guard viewModel.savedPlanID != nil else { return }
            await onSaveSucceeded()
        }
        .sheet(isPresented: $showActionSelect) {
            PlanActionSelectView(
                onActionSelected: addSelectedActionInfo,
                existingActionIds: Set(viewModel.selectedActions.map(\.actionId))
            )
        }
    }

    private var addActionButton: some View {
        Button {
            showActionSelect = true
        } label: {
            Label("添加动作", systemImage: "plus.circle.fill")
                .foregroundColor(theme.primary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(theme.surface)
                .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .disabled(viewModel.isSaving)
    }

    private var keyboard: some View {
        CustomNumberKeyboard(
            value: $keyboardManager.currentValue,
            isShowing: $keyboardManager.isShowing,
            step: keyboardManager.step,
            maxValue: keyboardManager.maxValue,
            isInteger: keyboardManager.isInteger,
            keyboardManager: keyboardManager
        )
        .onChange(of: keyboardManager.isShowing) { _, isShowing in
            if !isShowing { hideSystemKeyboard() }
        }
    }

    private func actionDetail(_ action: PlanAction) -> AnyView {
        AnyView(ActionDetailView(
            action: Action(
                id: action.actionId,
                external_id: String(action.actionId),
                name: action.name,
                name_en: action.nameEn,
                gifUrl: action.imageUrl,
                description: nil,
                description_en: nil,
                difficulty: nil,
                bodypart_id: action.bodyPartId,
                equipment_id: action.equipmentId,
                is_bilateral: false,
                target_muscle_ids: action.targetMuscleIds
            ),
            selectedTargetMuscleId: $selectedTargetMuscleId
        ))
    }

    private func addSelectedActionInfo(_ action: ActionInfo) {
        viewModel.selectedActions.append(PlanAction(
            id: Int.random(in: 100000...999999),
            actionId: action.id,
            name: action.name,
            imageUrl: action.imageUrl,
            nameEn: "",
            bodyPartId: 0,
            equipmentId: 0,
            targetMuscleIds: [],
            sets: [PlanSet()]
        ))
    }

    private func deleteAction(_ action: PlanAction) {
        viewModel.selectedActions.removeAll { $0.id == action.id }
    }

    private func toggleWeightUnit() {
        weightUnit = weightUnit == .kg ? .lbs : .kg
    }

    private func dismissKeyboard() {
        guard keyboardManager.isShowing else { return }
        keyboardManager.cancelKeyboard()
        hideSystemKeyboard()
    }

    private func hideSystemKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

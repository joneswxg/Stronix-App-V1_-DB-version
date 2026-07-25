import SwiftUI
import UIKit

struct EditPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: AppTheme
    let onSaveSuccess: ((TrainingPlan?) -> Void)?

    @StateObject private var viewModel: EditPlanViewModel
    @State private var showActionSelect = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var preventDismiss = false
    @State private var descriptionVisible = true
    @StateObject private var keyboardManager = CustomKeyboardManager()

    init(plan: TrainingPlan, onSaveSuccess: ((TrainingPlan?) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: EditPlanViewModel(plan: plan))
        self.onSaveSuccess = onSaveSuccess
    }

    private var totalVolume: Double {
        viewModel.actions.reduce(0) { total, action in
            total + action.sets.reduce(0) { setTotal, set in
                let weight = action.recordBilateral ? set.leftWeight + set.rightWeight : set.weight
                return setTotal + (weight.isFinite ? weight * Double(set.reps) : 0)
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        HStack {
                            Text("容量: \(Int(totalVolume)) kg")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        PlanFormNameEditor(
                            name: $viewModel.name,
                            description: $viewModel.description,
                            isDescriptionVisible: $descriptionVisible,
                            style: .labeled,
                            isDisabled: viewModel.isSaving,
                            dismissNumericKeyboard: keyboardManager.cancelKeyboard
                        )

                        HStack {
                            Text("训练动作").font(.system(size: 16, weight: .medium))
                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        if !viewModel.actions.isEmpty {
                            PlanFormActionList(
                                actions: $viewModel.actions,
                                weightUnit: "kg",
                                allowsUnitToggle: false,
                                notesConfiguration: nil,
                                usesCircularImage: false,
                                isDisabled: viewModel.isSaving,
                                keyboardManager: keyboardManager,
                                makeSet: makeSet,
                                onDelete: deleteAction,
                                onToggleUnit: {},
                                actionDetail: nil
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

                if keyboardManager.isShowing { keyboard }
            }
            .navigationTitle("编辑训练计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        if !preventDismiss { dismiss() }
                    }
                    .foregroundColor(theme.secondary)
                    .disabled(viewModel.isSaving || preventDismiss)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    PlanFormSaveButton(
                        isSaving: viewModel.isSaving,
                        isEnabled: !viewModel.name.isEmpty
                    ) {
                        Task { await save() }
                    }
                    .foregroundColor(theme.primary)
                    .fontWeight(.medium)
                }
            }
            .sheet(isPresented: $showActionSelect) {
                PlanActionSelectView(
                    onActionSelected: addAction,
                    existingActionIds: Set(viewModel.actions.map(\.actionId))
                )
            }
            .overlay(toast)
        }
    }

    private var addActionButton: some View {
        Button {
            showActionSelect = true
        } label: {
            Label("添加动作", systemImage: viewModel.actions.isEmpty ? "plus.circle.fill" : "plus.circle")
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

    private var toast: some View {
        VStack {
            Spacer()
            if showToast {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(theme.success)
                    Text(toastMessage).foregroundColor(theme.onSurface)
                }
                .padding()
                .background(theme.surface.opacity(0.9))
                .cornerRadius(12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 50)
        .animation(.easeInOut(duration: 0.3), value: showToast)
    }

    private func makeSet() -> EditPlanSet {
        EditPlanSet(
            id: Int.random(in: 100000...999999),
            order: viewModel.actions.count + 1,
            weight: 10,
            reps: 12,
            leftWeight: 0,
            rightWeight: 0
        )
    }

    private func deleteAction(_ action: EditPlanAction) {
        viewModel.actions.removeAll { $0.id == action.id }
    }

    private func addAction(_ action: ActionInfo) {
        viewModel.actions.append(EditPlanAction(
            id: Int.random(in: 100000...999999),
            actionId: action.id,
            name: action.name,
            imageUrl: action.imageUrl,
            restTime: 60,
            note: "",
            recordBilateral: false,
            isExpanded: false,
            sets: [makeSet()]
        ))
    }

    private func save() async {
        preventDismiss = true
        await viewModel.save()
        preventDismiss = false

        if let savedPlan = viewModel.savedPlan {
            toastMessage = "保存成功！"
            showToast = true
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            showToast = false
            onSaveSuccess?(savedPlan)
        } else if let errorMessage = viewModel.errorMessage {
            toastMessage = "保存失败: \(errorMessage)"
            showToast = true
        }
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

#Preview {
    Text("EditPlanView Preview")
}

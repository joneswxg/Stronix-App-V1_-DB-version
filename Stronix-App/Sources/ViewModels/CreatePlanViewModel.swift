import Foundation
import SwiftUI

@MainActor
final class CreatePlanViewModel: ObservableObject {
    @Published var planName = ""
    @Published var planNote = ""
    @Published var showPlanNote = false
    @Published var selectedActions: [PlanAction] = []
    @Published var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var savedPlanID: Int?

    private let useCase: CreateUserPlanUseCase

    init(useCase: CreateUserPlanUseCase) {
        self.useCase = useCase
    }

    func save() async {
        guard !isSaving else { return }

        isSaving = true
        errorMessage = nil
        savedPlanID = nil
        defer { isSaving = false }

        do {
            let response = try await useCase.execute(makeDraft())
            savedPlanID = response.plan_id
        } catch {
            errorMessage = AppError.map(error).userMessage
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    func consumeSavedPlanID() {
        savedPlanID = nil
    }

    private func makeDraft() -> PlanDraft {
        PlanDraft(
            name: planName,
            description: planNote.isEmpty ? nil : planNote,
            actions: selectedActions.map { action in
                PlanActionDraft(
                    actionID: action.actionId,
                    rest: action.restTime,
                    note: action.notes.isEmpty ? nil : action.notes,
                    recordBilateral: action.isLeftRightMode,
                    sets: action.sets.map { set in
                        PlanSetDraft(
                            weight: action.isLeftRightMode ? nil : set.weight,
                            reps: set.reps,
                            leftWeight: action.isLeftRightMode ? set.leftWeight : nil,
                            rightWeight: action.isLeftRightMode ? set.rightWeight : nil,
                            notes: set.notes.isEmpty ? nil : set.notes
                        )
                    }
                )
            }
        )
    }
}

import Foundation
import SwiftUI

@MainActor
final class EditPlanViewModel: ObservableObject {
    @Published var name: String
    @Published var description: String
    @Published var actions: [EditPlanAction]
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var savedPlan: TrainingPlan?

    private let planID: Int
    private let difficulty: String?
    private let duration: Int?
    private let updatePlan: any UpdatePlanExecuting

    init(plan: TrainingPlan, updatePlan: any UpdatePlanExecuting = UpdatePlanUseCase(repository: LocalPlanService.shared)) {
        planID = plan.id
        difficulty = plan.difficulty
        duration = plan.duration
        self.updatePlan = updatePlan
        name = plan.name
        description = plan.description ?? ""
        actions = plan.actions?.map { action in
            EditPlanAction(
                id: action.id,
                actionId: action.id,
                name: action.name,
                imageUrl: action.imageUrl,
                restTime: action.restTime,
                note: action.notes ?? "",
                recordBilateral: action.recordBilateral,
                isExpanded: false,
                sets: action.sets.enumerated().map { index, set in
                    EditPlanSet(
                        id: set.id,
                        order: index + 1,
                        weight: set.weight,
                        reps: set.reps,
                        leftWeight: set.leftWeight,
                        rightWeight: set.rightWeight
                    )
                }
            )
        } ?? []
    }

    func save() async {
        guard !isSaving else { return }

        isSaving = true
        errorMessage = nil
        savedPlan = nil
        defer { isSaving = false }

        do {
            savedPlan = try await updatePlan.execute(planID: planID, draft: draft)
        } catch {
            errorMessage = AppError.map(error).userMessage
        }
    }

    var draft: PlanDraft {
        PlanDraft(
            name: name,
            description: description.isEmpty ? nil : description,
            difficulty: difficulty,
            duration: duration,
            actions: actions.map { action in
                PlanActionDraft(
                    actionID: action.actionId,
                    rest: action.restTime,
                    note: action.note.isEmpty ? nil : action.note,
                    recordBilateral: action.recordBilateral,
                    sets: action.sets.map { set in
                        PlanSetDraft(
                            weight: action.recordBilateral ? nil : set.weight,
                            reps: set.reps,
                            leftWeight: action.recordBilateral ? set.leftWeight : 0,
                            rightWeight: action.recordBilateral ? set.rightWeight : 0
                        )
                    }
                )
            }
        )
    }
}

struct EditPlanAction: Identifiable {
    let id: Int
    let actionId: Int
    let name: String
    let imageUrl: String
    var restTime: Int
    var note: String
    var recordBilateral: Bool
    var isExpanded: Bool
    var sets: [EditPlanSet]

    init(
        id: Int,
        actionId: Int,
        name: String,
        imageUrl: String,
        restTime: Int,
        note: String,
        recordBilateral: Bool,
        isExpanded: Bool,
        sets: [EditPlanSet]
    ) {
        self.id = id
        self.actionId = actionId
        self.name = name
        self.imageUrl = imageUrl
        self.restTime = restTime
        self.note = note
        self.recordBilateral = recordBilateral
        self.isExpanded = isExpanded
        self.sets = sets
    }
}

typealias EditingAction = EditPlanAction

struct EditPlanSet: Identifiable {
    let id: Int
    let order: Int
    var weight: Double
    var reps: Int
    var leftWeight: Double
    var rightWeight: Double
}

typealias EditingSet = EditPlanSet

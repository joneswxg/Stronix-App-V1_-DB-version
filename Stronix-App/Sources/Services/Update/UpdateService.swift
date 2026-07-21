import Foundation

/// 旧版整库更新入口已从正式数据库启动流程移除。
/// DEBUG 整改重建只能通过 `-StronixRebuildLocalDatabase` 启动参数显式触发。
final class UpdateService {
    func checkAndUpdateDatabase() {
        print("ℹ️ UpdateService: 正式启动不再执行整库覆盖")
    }

    func forceDatabaseUpdate() {
        print("⚠️ UpdateService: 整库更新已禁用；DEBUG 下请使用 -StronixRebuildLocalDatabase")
    }

    func getUpdateStatus() -> String {
        "正式启动不执行整库覆盖"
    }
}

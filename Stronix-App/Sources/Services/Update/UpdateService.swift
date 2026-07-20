import Foundation

/// 旧版整库更新入口已从正式数据库启动流程移除。
/// 后续显式整改重建会通过独立的 DEBUG/测试工具实现。
final class UpdateService {
    func checkAndUpdateDatabase() {
        print("ℹ️ UpdateService: 正式启动不再执行整库覆盖")
    }

    func forceDatabaseUpdate() {
        print("⚠️ UpdateService: 整库更新已禁用，请使用显式整改工具")
    }

    func getUpdateStatus() -> String {
        "正式启动不执行整库覆盖"
    }
}

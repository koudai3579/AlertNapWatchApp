import CoreMotion
import Foundation
import Combine

// モーション（加速度）を監視し、手首が動いているかどうかを検出するクラス
class MotionManager: ObservableObject {
    
    private let motionManager = CMMotionManager()        // 加速度センサー管理オブジェクト
    private let updateInterval = 1.0                     // センサーの更新間隔（秒）
    @Published var isWristMoving: Bool = false           // 手首が動いているかどうかを表すフラグ（Viewなどにバインド可能）
    private var lastAcceleration: CMAcceleration?        // 前回の加速度データを保持して差分計算に使う

    // モーション検出の開始
    func start() {
        // 加速度センサーが利用可能かチェック
        guard motionManager.isAccelerometerAvailable else { return }

        // センサーの更新間隔を設定
        motionManager.accelerometerUpdateInterval = updateInterval

        // センサー更新の開始（メインスレッドで取得）
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let acceleration = data?.acceleration else { return }

            // 前回の加速度と比較して変化量を計算
            if let last = self.lastAcceleration {
                let dx = acceleration.x - last.x
                let dy = acceleration.y - last.y
                let dz = acceleration.z - last.z
                let delta = sqrt(dx*dx + dy*dy + dz*dz) // 3軸方向の変化量の大きさ
                // 変化量がしきい値を超えていれば「動いている」と判断（しきい値は 0.02）
                self.isWristMoving = delta > 0.02
            }
            // 今回の加速度を次回の比較用として保存
            self.lastAcceleration = acceleration
        }
    }

    // モーション検出の停止
    func stop() {
        motionManager.stopAccelerometerUpdates()
        lastAcceleration = nil
        isWristMoving = true // 停止時は一律「動いている」扱いに（必要に応じて false にしてもよい）
    }
}

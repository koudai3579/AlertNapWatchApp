//準備(メモ)
//Capabilities → HealthKit の追加
//Info → Privacy - Health Update Usage Description キーの設定
//Info → Privacy - Health Share Usage Description　キーの設定

import Foundation
import HealthKit
import Combine

// HealthKitを用いて心拍数（bpm）を監視するクラス
class HeartRateManager: ObservableObject {
    
    private var healthStore = HKHealthStore()                // HealthKit ストアインスタンス
    private var heartRateQuery: HKAnchoredObjectQuery?       // リアルタイムクエリ用
    private var anchor: HKQueryAnchor?                       // クエリの継続に使うアンカー
    @Published var heartRate: Double = 0.0                   // 現在の心拍数

    init() {
        // 起動時には何もしない。必要になったら `start()` を呼ぶ。
    }

    // 心拍数の監視を開始するメソッド
    func start() {
        // 心拍数のデータ型を取得
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        // HealthKit から読み取り権限をリクエスト（共有は不要なので空配列）
        healthStore.requestAuthorization(toShare: [], read: [heartRateType]) { success, error in
            if success {
                // 認可が通ったらクエリを開始
                self.startHeartRateQuery()
            } else {
                print("HealthKit authorization failed: \(String(describing: error))")
            }
        }
    }

    // 心拍数の監視を停止
    func stop() {
        // 実行中のクエリがあれば停止
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }

        // 心拍数をリセット（UI上で反映させるためにメインスレッドで更新）
        DispatchQueue.main.async {
            self.heartRate = 0.0
        }
    }

    // 心拍数のリアルタイム監視用クエリを構築して実行
    private func startHeartRateQuery() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        // 現在時刻以降のデータのみ対象とする
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)

        // 初回取得＋以降の更新を受け取るHKAnchoredObjectQueryを作成
        heartRateQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samplesOrNil, _, newAnchor, _ in
            // 初回取得分の処理
            self?.anchor = newAnchor
            self?.process(samples: samplesOrNil)
        }

        // リアルタイム更新分の処理
        heartRateQuery?.updateHandler = { [weak self] _, samplesOrNil, _, newAnchor, _ in
            self?.anchor = newAnchor
            self?.process(samples: samplesOrNil)
        }

        // クエリを実行
        if let query = heartRateQuery {
            healthStore.execute(query)
        }
    }

    // 取得したサンプルから最新の心拍数を計算して反映
    private func process(samples: [HKSample]?) {
        // 心拍数のサンプルに変換
        guard let heartSamples = samples as? [HKQuantitySample] else { return }

        DispatchQueue.main.async {
            // 最も新しいサンプルを取得
            if let latestSample = heartSamples.last {
                // 単位（count/minute）で bpm を取得
                let bpm = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                self.heartRate = bpm
            }
        }
    }
}

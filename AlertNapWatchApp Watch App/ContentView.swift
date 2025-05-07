//一括インデント：全選択→Controlキー＋「I」
import SwiftUI
import WatchKit

struct ContentView: View {
    
    // インスタンスの初期化
    @StateObject private var heartRateManager = HeartRateManager() // 心拍数検出管理
    @StateObject private var motionManager = MotionManager()       // 腕の動き検出管理
    
    // 状態管理
    @State private var isDetectionOn: Bool = false                // 検出機能ON/OFFの状態
    @State private var sensitivity: Sensitivity = .medium         // 検出感度（初期値：中）
    @State private var showSensitivityInfo = false                // 感度説明アラート表示用
    @State private var baselineHeartRate: Double? = nil           // 基準心拍数（最初の正常時平均）
    @State private var heartRateHistory: [Double] = []            // 基準値計算用の心拍数履歴
    @State private var dropThreshold: Double = 5.0                // 心拍数低下の検知閾値（感度で変動）
    
    // 感度設定（保存／読込対応）
    enum Sensitivity: String, CaseIterable {
        case low = "低"    // 感度：低（誤検知は少ないが、検出しにくい）
        case medium = "中" // 感度：中（バランス型）
        case high = "高"   // 感度：高（小さな変化も検出するが、誤検知しやすい）
        
        // ユーザーが以前に選択した感度設定をUserDefaultsから読み込む
        // 保存されていない場合、デフォルトで「中」を返す
        static func savedSensitivity() -> Sensitivity {
            if let saved = UserDefaults.standard.string(forKey: "sensitivity") {
                // 保存されている文字列から感度を復元（失敗した場合は .medium を使用）
                return Sensitivity(rawValue: saved) ?? .medium
            }
            return .medium
        }
        // 現在の感度設定をUserDefaultsに保存する
        func save() {
            UserDefaults.standard.set(self.rawValue, forKey: "sensitivity")
        }
    }
    
    
    // 感度に応じて心拍数の閾値を変更
    private func updateThreshold(for sensitivity: Sensitivity) {
        switch sensitivity {
        case .low:
            dropThreshold = 7.0
        case .medium:
            dropThreshold = 5.0
        case .high:
            dropThreshold = 3.0
        }
        print("感度変更: \(sensitivity.rawValue)")
    }
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.blue.opacity(0.6), Color.purple.opacity(0.4)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    
                    // タイトル
                    Text("うたた寝アラーム")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .shadow(radius: 2)
                    
                    // 検知オン/オフトグル
                    Toggle(isOn: $isDetectionOn) {
                        Text("検知をオンにする")
                            .font(.headline)
                    }
                    .onChange(of: isDetectionOn) { _, newValue in
                        if newValue {
                            heartRateManager.start()
                            motionManager.start()
                            print("検知がONになりました")
                        } else {
                            heartRateManager.stop()
                            motionManager.stop()
                            baselineHeartRate = nil
                            heartRateHistory = []
                            print("検知がOFFになりました")
                        }
                    }
                    
                    // 感度選択と説明
                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            Text("感度")
                                .font(.subheadline)
                            
                            Button(action: {
                                showSensitivityInfo = true
                            }) {
                                Image(systemName: "questionmark.circle")
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .alert("感度について", isPresented: $showSensitivityInfo) {
                                Button("OK", role: .cancel) {}
                            } message: {
                                Text("感度が高いほど、小さな変化でも検出しますが、誤検出も増える可能性があります。")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        HStack {
                            ForEach(Sensitivity.allCases, id: \.self) { level in
                                Button(action: {
                                    sensitivity = level
                                    sensitivity.save()
                                    updateThreshold(for: level)
                                }) {
                                    Text(level.rawValue)
                                        .padding(8)
                                        .background(sensitivity == level ? Color.blue : Color.gray)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 状態表示エリア
                    VStack(spacing: 4) {
                        Text("現在の心拍数: \(Int(heartRateManager.heartRate)) BPM")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("腕の動き検知: \(motionManager.isWristMoving ? "活動中" : "静止中")")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("検知状態: \(isDetectionOn ? "オン" : "オフ")")
                        Text("感度設定: \(sensitivity.rawValue)")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                .padding([.leading, .trailing, .bottom])
            }
            
            // 心拍数が変化した時の処理
            .onChange(of: heartRateManager.heartRate) { newHeartRate in
                // ① 基準心拍数がまだ無い場合 → 心拍数履歴を10件集めて平均を基準にする
                if baselineHeartRate == nil {
                    if heartRateHistory.count < 10 {
                        heartRateHistory.append(newHeartRate)
                        print("最新の心拍数: \(newHeartRate)")
                    }
                    if heartRateHistory.count >= 10 {
                        baselineHeartRate = heartRateHistory.reduce(0, +) / Double(heartRateHistory.count)
                        print("基準とする心拍数: \(String(describing: baselineHeartRate))")
                    }
                } else {
                    // ② 基準が設定済みなら、動きと心拍の状態を判定
                    if motionManager.isWristMoving {
                        print("現在手は動いているようです（活動中）")
                        return
                    }
                    if newHeartRate < baselineHeartRate! - dropThreshold {
                        WKInterfaceDevice.current().play(.notification) // 通知振動
                        print("眠気を検出（\(newHeartRate) < \(baselineHeartRate! - dropThreshold)）")
                    } else {
                        print("覚醒時の心拍数。平均: \(baselineHeartRate!), 現在: \(newHeartRate)")
                    }
                }
            }
        }
        .onAppear {
            // 起動時に保存されていた感度を読み込み、閾値を反映
            sensitivity = Sensitivity.savedSensitivity()
            updateThreshold(for: sensitivity)
        }
    }
}

// プレビュー
#Preview {
    ContentView()
}

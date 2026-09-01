# AssetRebalancer

![Swift](https://img.shields.io/badge/Swift-5.9+-F05138?logo=swift&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-iOS_17+-007AFF?logo=apple&logoColor=white)
![CI](https://github.com/Neroal/asset-rebalancer-ios/actions/workflows/ci.yml/badge.svg)
![License](https://img.shields.io/badge/License-MIT-green)

一款 iOS 投資組合管理 App，協助使用者追蹤資產配置，並透過自動化再平衡建議維持理想的投資比例。

## 功能特色

- **多元資產追蹤**：支援台股、美股、債券與現金，統一以新台幣計價
- **即時報價**：從台灣證交所（TWSE）與 Yahoo Finance 取得即時股價，並自動換算美元／新台幣匯率；台股盤中報價近即時更新，下拉即可強制刷新
- **智慧再平衡**：根據可自訂的目標配置與偏差門檻，計算買進／賣出建議
- **配置模板**：內建積極型（80/15/5）、穩健型（60/30/10）、保守型（40/40/20）三種目標配置，一鍵套用
- **視覺化儀表板**：以環形圓餅圖直觀呈現投資組合配置與偏差狀況
- **雲端同步**：透過 Google 或 Apple 登入驗證，即時同步資料至 Firebase Firestore
- **雙語介面**：支援繁體中文與英文

## 截圖

<!-- 在此新增 App 截圖 -->

## 系統需求

- iOS 17.0+
- Xcode 26.0+
- Swift 5.9+

## 快速開始

1. Clone 儲存庫：
   ```bash
   git clone https://github.com/Neroal/asset-rebalancer-ios.git
   ```

2. 設定 Firebase：
   - 在 [Firebase Console](https://console.firebase.google.com/) 建立專案
   - 啟用 **Authentication**（Google 登入與 Apple 登入）以及 **Firestore Database**
   - 下載 `GoogleService-Info.plist` 並放置於 `AssetRebalancer/` 資料夾內

   > **注意**：`GoogleService-Info.plist` 已透過 `.gitignore` 排除於版本控制之外。請參考 `GoogleService-Info.template.plist` 了解所需的金鑰格式。

3. 設定 Firestore 安全規則：
   - 在 Firebase Console 前往 **Firestore Database → 規則**
   - 設定以下規則，確保每位使用者僅能存取自己的資料：
     ```
     rules_version = '2';
     service cloud.firestore {
       match /databases/{database}/documents {
         match /users/{userId}/{document=**} {
           allow read, write: if request.auth != null
                              && request.auth.uid == userId;
         }
       }
     }
     ```

4. 以 Xcode 開啟 `AssetRebalancer.xcodeproj`

5. 安裝相依套件（透過 Swift Package Manager 自動解析）

6. 選擇模擬器或裝置後，建置並執行

## 專案結構

```
AssetRebalancer/
├── AssetRebalancerApp.swift          # App 進入點與 Firebase 初始化
├── ContentView.swift                 # 根導航（登入 / 主畫面切換）
├── Models/
│   ├── Asset.swift                   # 資產模型、市場類型、目標配置與模板
│   └── Portfolio.swift               # 投資組合摘要與再平衡操作
├── ViewModels/
│   ├── AuthViewModel.swift           # Firebase 驗證（Google / Apple 登入）
│   ├── PortfolioViewModel.swift      # 主要狀態管理 ViewModel
│   └── LanguageViewModel.swift       # 中文 / 英文語言切換與 UI 字串
├── Services/
│   ├── FirestoreService.swift        # Firestore 資料讀寫
│   ├── StockAPIService.swift         # 台股 / 美股報價（含快取）
│   └── ExchangeRateService.swift     # 美元 → 新台幣匯率換算
├── Utils/
│   └── Rebalancer.swift              # 再平衡計算邏輯（純函式）
└── Views/
    ├── Screens/
    │   ├── MainTabView.swift         # 分頁導航
    │   ├── LoginView.swift           # 登入畫面
    │   ├── DashboardView.swift       # 投資組合總覽儀表板
    │   ├── AssetsView.swift          # 資產列表
    │   ├── AddAssetView.swift        # 新增資產
    │   ├── EditAssetView.swift       # 編輯資產
    │   └── SettingsView.swift        # 設定（目標配置、模板、語言）
    └── Components/
        ├── AssetRowView.swift        # 資產列表行元件
        ├── PieChartView.swift        # 自訂環形圖表
        ├── DeviationRow.swift        # 偏差顯示列
        └── AllocationSlider.swift    # 配置比例滑桿

AssetRebalancerTests/
└── RebalancerTests.swift             # 再平衡與配置邏輯單元測試
```

## 技術棧

| 領域 | 技術 |
|------|------|
| UI 框架 | SwiftUI |
| 架構 | MVVM + `@EnvironmentObject` 依賴注入 |
| 並發處理 | Swift Concurrency（async/await + Actor）|
| 後端 | Firebase Auth + Firestore |
| 驗證 | Google 登入、Apple 登入 |
| 股票報價 | TWSE API、Yahoo Finance API |
| 匯率 | ExchangeRate-API（含備援 API）|
| 測試 / CI | Swift Testing、GitHub Actions |

## 再平衡邏輯

核心功能計算各資產類別與使用者目標配置的偏差程度：

- **預設目標**：股票 60%、債券 30%、現金 10%（可自訂或套用內建模板）
- **偏差門檻**：預設 5%（可調整範圍 1% 至 20%）
- 當任一類別的實際百分比超過門檻時，App 將建議具體的新台幣買進或賣出金額

## 快取策略

為減少 API 呼叫次數並提升效能：

- 台股價格：盤中（週一至週五 09:00–13:45）快取 **60 秒**，盤後 **1 小時**
- 美股價格：快取 **1 小時**
- 匯率：快取 **24 小時**
- 下拉更新會略過快取，強制取得最新報價

## 測試與 CI

- 單元測試涵蓋再平衡計算、偏差門檻邊界、金額格式化與配置模板：
  ```bash
  xcodebuild test -project AssetRebalancer.xcodeproj \
    -scheme AssetRebalancer \
    -destination 'platform=iOS Simulator,name=iPhone 16'
  ```
- GitHub Actions 於每個 PR 與 push to main 時自動執行建置與測試（見 [ci.yml](.github/workflows/ci.yml)）

## 授權條款

本專案採用 MIT 授權條款，詳情請見 [LICENSE](LICENSE) 檔案。

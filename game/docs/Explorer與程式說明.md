# Explorer 與程式放置

用 Studio 直接開啟 DragonAwakening-Atelier-v9.rbxl，程式和模型都已放好。檔案夾版可以透過 default.project.json 與 Rojo 重建。

| Explorer | 檔案位置與用途 |
|---|---|
| Workspace/SkyIslands | src/Workspace/SkyIslands.rbxmx；七座島的實體場景 |
| Workspace/DragonSpawn | src/Workspace/DragonSpawn.rbxmx；初始出生點 |
| ReplicatedStorage/DragonShared | src/ReplicatedStorage/DragonShared；共用設定、模型、畫面模組 |
| ServerScriptService/DragonServer | src/ServerScriptService/DragonServer；權威玩法與驗證 |
| StarterGui/DragonUI/Controller | src/StarterGui/DragonUI/Controller.client.luau；建立六個分頁與互動介面 |
| ReplicatedStorage/DragonRemotes | 由 GameServer 建立；購買／裝備／攻擊請求與飛行方向訊號 |
| Workspace/DragonWorld | 由 World 建立；怪物狀態、NPC、互動點及龍的外觀描述 |

## 畫面與外觀

UI/Components 為共用元件；UI/Preview 顯示 3D 預覽；UI/ApprovedArt 顯示內嵌裝備與怪物設計圖；UI/MapView 和 Cartography 顯示地圖與路標。Controller 建立背包、套裝、怪物、商店、龍與地圖六個分頁。

NativeModel 從 BakedArt/PolishedModels 複製 62 個外觀；環境放置從 BakedArt/Scenery 複製 37 個模板。VisualChunks、SceneryChunks、WorldChunks 分別保留外觀、環境及七島配方，對應 art/visual-recipes.json、scenery-recipes.json、world-scenes.json。

UI/RidePresentation、RideMotion、CompanionRenderer 與 WorldRenderer 使用共同的平滑姿態來顯示騎手、龍、裝備與鏡頭。顯示用角色不參與傷害、交易或碰撞判定。

## 伺服器

GameServer 協調服務；Domain 處理純經濟、裝備、升級與掉寶；Settings 保存實際掉落權重；RequestGuard 驗證請求和頻率；CombatRules 驗證距離與擊殺；ProfileStore 處理存檔與工作階段；TravelService 和 TravelRules 計算飛行位置、碰撞、等級門檻及落地。

客戶端只提交意圖和物品／目標識別，不可提交價格、獎勵、傷害或飛行座標。所有原始腳本都保留在 src 對應的 Explorer 路徑。

新版模型細節與驗收：[v7美術與驗收](v7美術與驗收.md)。


最新版涵蓋、分散規則與驗收請見 [v8怪物分布與驗收](v8怪物分布與驗收.md)。


本次 v9 的再次細化與驗收請見 [v9細化與驗收](v9細化與驗收.md)。

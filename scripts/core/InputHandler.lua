-- ============================================================================
-- 星河战姬 Starkyries - 输入处理器
-- 负责键盘/触摸输入、UI 交互分发
-- ============================================================================

local InputHandler = {}

-- ============================================================================
-- 依赖模块（延迟加载）
-- ============================================================================
local Game, Shop, BridgeUpgrade, VirtualJoystick
local MainMenuUI, ShipSelectUI, WeaponSelectUI, ShopUI, Overlays
local OptionsUI, GalleryUI

local function LoadDependencies()
    if not Game then
        Game = require("core.Game")
        Shop = require("core.Shop")
        BridgeUpgrade = require("core.BridgeUpgrade")
        VirtualJoystick = require("ui.VirtualJoystick")
        MainMenuUI = require("ui.MainMenuUI")
        ShipSelectUI = require("ui.ShipSelectUI")
        WeaponSelectUI = require("ui.WeaponSelectUI")
        ShopUI = require("ui.ShopUI")
        Overlays = require("ui.Overlays")
        OptionsUI = require("ui.OptionsUI")
        GalleryUI = require("ui.GalleryUI")
    end
end

-- ============================================================================
-- 状态
-- ============================================================================
InputHandler.mainMenuActive = false
InputHandler.optionsActive = false
InputHandler.galleryActive = false
InputHandler.shipSelectActive = false
InputHandler.weaponSelectActive = false
InputHandler.selectedShipConfig = nil
InputHandler.selectedWeaponId = nil

-- 回调
InputHandler.onShipSelected = nil       -- function(ship) 战舰选择完成
InputHandler.onWeaponSelected = nil     -- function(ship, weaponId) 武器选择完成
InputHandler.onBackToMainMenu = nil     -- function() 返回主菜单
InputHandler.onBackToShipSelect = nil   -- function() 返回战舰选择
InputHandler.onEnterShop = nil          -- function() 进入商店
InputHandler.onExitShop = nil           -- function() 退出商店
InputHandler.onRestart = nil            -- function() 重新开始
InputHandler.onBridgeUpgradeSelect = nil    -- function(index) 选择升级
InputHandler.onBridgeUpgradeRefresh = nil   -- function() 刷新升级

-- ============================================================================
-- 初始化
-- ============================================================================

function InputHandler.Init()
    InputHandler.mainMenuActive = true
    InputHandler.optionsActive = false
    InputHandler.galleryActive = false
    InputHandler.shipSelectActive = false
    InputHandler.weaponSelectActive = false
    InputHandler.selectedShipConfig = nil
    InputHandler.selectedWeaponId = nil
end

function InputHandler.SetMainMenuActive(active)
    InputHandler.mainMenuActive = active
end

function InputHandler.SetOptionsActive(active)
    InputHandler.optionsActive = active
end

function InputHandler.SetGalleryActive(active)
    InputHandler.galleryActive = active
end

function InputHandler.SetShipSelectActive(active)
    InputHandler.shipSelectActive = active
end

function InputHandler.SetWeaponSelectActive(active)
    InputHandler.weaponSelectActive = active
end

function InputHandler.SetSelectedShipConfig(config)
    InputHandler.selectedShipConfig = config
end

-- ============================================================================
-- 获取移动输入
-- ============================================================================

function InputHandler.GetMovementInput()
    LoadDependencies()
    
    local moveX, moveY = 0, 0
    
    -- 键盘输入
    if input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP) then moveY = 1 end
    if input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) then moveY = -1 end
    if input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT) then moveX = -1 end
    if input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT) then moveX = 1 end
    
    -- 虚拟摇杆输入（叠加）
    if VirtualJoystick.IsEnabled() then
        local joyX, joyY = VirtualJoystick.GetDirection()
        if math.abs(joyX) > 0.01 or math.abs(joyY) > 0.01 then
            moveX = joyX
            moveY = joyY
        end
    end
    
    return moveX, moveY
end

-- ============================================================================
-- 主更新函数
-- ============================================================================

function InputHandler.Update(dt, gameState, bridgeUpgradeState)
    LoadDependencies()
    
    local sw = graphics:GetWidth()
    local sh = graphics:GetHeight()
    
    -- 选项界面输入（最高优先级）
    if InputHandler.optionsActive then
        InputHandler.HandleOptionsInput(sw, sh)
        return "options"
    end
    
    -- 图鉴界面输入
    if InputHandler.galleryActive then
        InputHandler.HandleGalleryInput(sw, sh)
        return "gallery"
    end
    
    -- 主菜单界面输入
    if InputHandler.mainMenuActive then
        InputHandler.HandleMainMenuInput(sw, sh)
        return "main_menu"
    end
    
    -- 战舰选择界面输入
    if InputHandler.shipSelectActive then
        InputHandler.HandleShipSelectInput(sw, sh)
        return "ship_select"
    end
    
    -- 武器选择界面输入
    if InputHandler.weaponSelectActive then
        InputHandler.HandleWeaponSelectInput(sw, sh)
        return "weapon_select"
    end
    
    -- 商店输入
    if gameState == Game.States.SHOP then
        InputHandler.HandleShopInput(sw, sh)
        return "shop"
    end
    
    -- 舰桥升级输入
    if bridgeUpgradeState and bridgeUpgradeState.active then
        InputHandler.HandleBridgeUpgradeInput(sw, sh, bridgeUpgradeState)
        return "bridge_upgrade"
    end
    
    -- 游戏结束/胜利输入
    if gameState == Game.States.GAME_OVER or gameState == Game.States.VICTORY then
        InputHandler.HandleGameOverInput(sw, sh)
        return "game_over"
    end
    
    return "playing"
end

-- ============================================================================
-- 选项界面输入
-- ============================================================================

function InputHandler.HandleOptionsInput(sw, sh)
    LoadDependencies()
    
    OptionsUI.HandleInput()
    OptionsUI.HandleTouch(sw, sh)
end

-- ============================================================================
-- 图鉴界面输入
-- ============================================================================

function InputHandler.HandleGalleryInput(sw, sh)
    LoadDependencies()
    
    GalleryUI.HandleInput()
    GalleryUI.HandleTouch(sw, sh)
end

-- ============================================================================
-- 主菜单输入
-- ============================================================================

function InputHandler.HandleMainMenuInput(sw, sh)
    LoadDependencies()
    
    MainMenuUI.HandleInput()
    MainMenuUI.HandleTouch(sw, sh)
end

-- ============================================================================
-- 战舰选择输入
-- ============================================================================

function InputHandler.HandleShipSelectInput(sw, sh)
    LoadDependencies()
    
    local result, action = ShipSelectUI.HandleInput()
    if action == "back" then
        -- 返回主菜单
        if InputHandler.onBackToMainMenu then
            InputHandler.onBackToMainMenu()
        end
        return
    end
    
    local touchResult, touchAction = ShipSelectUI.HandleTouch(sw, sh)
    if touchAction == "back" then
        -- 返回主菜单
        if InputHandler.onBackToMainMenu then
            InputHandler.onBackToMainMenu()
        end
    end
end

-- ============================================================================
-- 武器选择输入
-- ============================================================================

function InputHandler.HandleWeaponSelectInput(sw, sh)
    LoadDependencies()
    
    local result, action = WeaponSelectUI.HandleInput()
    if action == "back" then
        -- 返回战舰选择
        if InputHandler.onBackToShipSelect then
            InputHandler.onBackToShipSelect()
        end
        return
    end
    
    local touchResult, touchAction = WeaponSelectUI.HandleTouch(sw, sh)
    if touchAction == "back" then
        -- 返回战舰选择
        if InputHandler.onBackToShipSelect then
            InputHandler.onBackToShipSelect()
        end
    end
end

-- ============================================================================
-- 商店输入
-- ============================================================================

function InputHandler.HandleShopInput(sw, sh)
    LoadDependencies()
    
    -- 调试面板：T键切换
    ShopUI.HandleDebugKey()
    
    -- 调试面板：滚动处理
    ShopUI.HandleDebugPanelScroll()
    
    -- 调试面板：点击处理（优先于正常商店输入）
    if ShopUI.showDebugPanel then
        local handled = ShopUI.HandleDebugPanelTouch(
            Game.player,
            function(weaponId, tier)  -- onAddWeapon
                -- 添加武器到玩家装备（与正常商店购买相同逻辑）
                local Weapons = require("config.weapons")
                local Player = require("entities.Player")
                local weaponDef = Weapons.Get(weaponId)
                tier = tier or 1
                if weaponDef then
                    Game.player.weapons = Game.player.weapons or {}
                    local maxSlots = Game.player.maxWeaponSlots or 6
                    local freeSlot = Player.GetFreeSlot(maxSlots)
                    if freeSlot then
                        -- 有空闲槽位，直接添加
                        local weapon = Player.AddWeapon(weaponId, freeSlot, tier)
                        print("[Debug] 添加武器: " .. weaponDef.name .. " T" .. tier .. " slot=" .. freeSlot)
                    else
                        -- 武器槽已满，尝试合成（同ID + 同Tier + Tier<4）
                        local existingWeapon = nil
                        for _, w in ipairs(Game.player.weapons) do
                            if w.id == weaponId and w.tier == tier and tier < 4 then
                                existingWeapon = w
                                break
                            end
                        end
                        
                        if existingWeapon then
                            -- 合成升级
                            existingWeapon.tier = existingWeapon.tier + 1
                            Player.UpdateWeaponTierVisual(existingWeapon)
                            print("[Debug] 合成升级: " .. weaponDef.name .. " → T" .. existingWeapon.tier)
                        elseif tier >= 4 then
                            print("[Debug] T4武器无法合成")
                        else
                            print("[Debug] 武器槽已满，无同类武器可合成")
                        end
                    end
                end
            end,
            function(moduleId)  -- onAddModule
                -- 添加模块到玩家装备
                local Modules = require("config.modules")
                local moduleDef = Modules.Get(moduleId)
                if moduleDef then
                    Game.player.modules = Game.player.modules or {}
                    local owned = Game.player.modules[moduleId] or 0
                    local maxStack = moduleDef.maxStack or 1
                    if owned < maxStack then
                        Game.player.modules[moduleId] = owned + 1
                        -- 应用模块效果
                        if moduleDef.effect then
                            moduleDef.effect(Game.player)
                        end
                        print("[Debug] 添加模块: " .. moduleDef.name .. " (" .. (owned + 1) .. "/" .. maxStack .. ")")
                    else
                        print("[Debug] 模块已达上限: " .. moduleDef.name)
                    end
                end
            end
        )
        if handled then
            return  -- 调试面板消费了输入，不处理正常商店输入
        end
    end
    
    -- 调试面板打开时，屏蔽正常键盘输入
    if ShopUI.showDebugPanel then
        return
    end
    
    -- 键盘输入
    if input:GetKeyPress(KEY_W) or input:GetKeyPress(KEY_UP) then
        Shop.selectedIndex = Shop.selectedIndex - 2
        if Shop.selectedIndex < 1 then Shop.selectedIndex = Shop.selectedIndex + 4 end
    end
    if input:GetKeyPress(KEY_S) or input:GetKeyPress(KEY_DOWN) then
        Shop.selectedIndex = Shop.selectedIndex + 2
        if Shop.selectedIndex > 4 then Shop.selectedIndex = Shop.selectedIndex - 4 end
    end
    if input:GetKeyPress(KEY_A) or input:GetKeyPress(KEY_LEFT) then
        Shop.SelectPrev()
    end
    if input:GetKeyPress(KEY_D) or input:GetKeyPress(KEY_RIGHT) then
        Shop.SelectNext()
    end
    if input:GetKeyPress(KEY_SPACE) then
        local success = Shop.BuyItem(Shop.selectedIndex)
        if success then
            Shop.GenerateItems(Shop.currentWave)
        end
    end
    if input:GetKeyPress(KEY_R) then
        Shop.Refresh(Shop.currentWave)
    end
    if input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_KP_ENTER) then
        if InputHandler.onExitShop then
            InputHandler.onExitShop()
        end
    end
    
    -- 触摸/点击输入
    ShopUI.HandleTouch(sw, sh, Shop,
        function(index)  -- onBuy
            local success = Shop.BuyItem(index)
            if success then
                -- 购买成功后不重新生成，保留锁定的物品
            end
        end,
        function()  -- onRefresh
            Shop.Refresh(Shop.currentWave)
        end,
        function()  -- onContinue
            if InputHandler.onExitShop then
                InputHandler.onExitShop()
            end
        end,
        function(index)  -- onLock
            Shop.ToggleLock(index)
        end,
        function(weaponIndex, recycleValue)  -- onRecycle
            -- 回收武器：移除武器并获得晶体
            if Game.player.weapons and Game.player.weapons[weaponIndex] then
                local weapon = Game.player.weapons[weaponIndex]
                
                -- 清理场景中的炮塔节点
                if weapon.turretNode then
                    weapon.turretNode:Remove()
                    weapon.turretNode = nil
                end
                
                -- 从武器数组移除
                -- 🔧 统一数据源后，Game.player.weapons 就是 Player.weapons，无需额外同步
                table.remove(Game.player.weapons, weaponIndex)
                
                -- 获得晶体
                Game.player.crystals = (Game.player.crystals or 0) + recycleValue
                
                -- 重新计算武器效果和套装加成
                Game.RecalculateWeaponEffects()
            end
        end,
        Game.player,  -- player 参数
        function(index1, index2)  -- onMerge
            -- 合成已装备的武器
            local success, message = Shop.MergeEquippedWeapons(index1, index2)
            if success then
                print("[Shop] 武器合成: " .. message)
                -- 重新计算武器效果和套装加成
                Game.RecalculateWeaponEffects()
            end
        end
    )
end

-- ============================================================================
-- 舰桥升级输入
-- ============================================================================

function InputHandler.HandleBridgeUpgradeInput(sw, sh, bridgeUpgradeState)
    LoadDependencies()
    
    -- 键盘输入
    if input:GetKeyPress(KEY_W) or input:GetKeyPress(KEY_UP) then
        BridgeUpgrade.SelectPrev()
    end
    if input:GetKeyPress(KEY_S) or input:GetKeyPress(KEY_DOWN) then
        BridgeUpgrade.SelectNext()
    end
    if input:GetKeyPress(KEY_SPACE) then
        if InputHandler.onBridgeUpgradeSelect then
            InputHandler.onBridgeUpgradeSelect(BridgeUpgrade.GetSelectedIndex())
        end
    end
    if input:GetKeyPress(KEY_R) then
        if InputHandler.onBridgeUpgradeRefresh then
            InputHandler.onBridgeUpgradeRefresh()
        end
    end
    
    -- 触摸/点击输入
    Overlays.HandleBridgeUpgradeTouch(sw, sh, bridgeUpgradeState,
        function(index)  -- onSelect
            if InputHandler.onBridgeUpgradeSelect then
                InputHandler.onBridgeUpgradeSelect(index)
            end
        end,
        function()  -- onRefresh
            if InputHandler.onBridgeUpgradeRefresh then
                InputHandler.onBridgeUpgradeRefresh()
            end
        end,
        BridgeUpgrade.GetRefreshCost(),
        Game.player.crystals
    )
    
    -- 属性面板滚动
    Overlays.HandleStatsScroll(sw, sh, bridgeUpgradeState)
end

-- ============================================================================
-- 游戏结束输入
-- ============================================================================

function InputHandler.HandleGameOverInput(sw, sh)
    LoadDependencies()
    
    -- 键盘输入
    if input:GetKeyPress(KEY_R) then
        if InputHandler.onRestart then
            InputHandler.onRestart()
        end
    end
    
    -- 触摸/点击输入 - 根据游戏状态使用不同的触摸处理
    local restartCallback = function()
        if InputHandler.onRestart then
            InputHandler.onRestart()
        end
    end
    
    if Game.currentState == Game.States.VICTORY then
        Overlays.HandleVictoryTouch(sw, sh, restartCallback)
    else
        Overlays.HandleGameOverTouch(sw, sh, restartCallback)
    end
end

return InputHandler

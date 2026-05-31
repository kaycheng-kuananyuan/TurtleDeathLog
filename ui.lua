-- ==========================================================
-- UI.lua - Turtle Death Log (V1.4.0 - 新增玩家姓名精准查询)
-- ==========================================================

local L = {}
if GetLocale() == "zhCN" then
    L["TITLE"] = "全网死亡记录查询 (TDL v1.4.0)"
    L["NAME_SEARCH"] = "玩家姓名"
    L["MIN_LVL"] = "最低"
    L["MAX_LVL"] = "最高"
    L["ZONE"] = "查询(地点/死因)"
    L["BTN_SEARCH"] = "查询"
    L["BTN_SYNC"] = "刷新同步"
    L["BTN_OLDER"] = "查询更久"
    L["BTN_RECENT"] = "显示最近7天"
    L["BTN_FIX"] = "整理/查重"
    L["BTN_BUG"] = "报告另类死亡"
    L["BTN_START"] = "开启插件"
    L["BTN_ON"] = "插件已开启"
    L["JOIN_DESC"] = "数据共享协议状态："
    L["LOCK_WARNING"] = "无私共享方能获取知识。\n\n请先点击右下角的【开启插件】\n承诺共享您的收录数据，以解锁全网查询功能！"
    L["H_NAME"] = "姓名"
    L["H_LVL"] = "等级"
    L["H_ZONE"] = "区域位置"
    L["H_CAUSE"] = "致命原因"
    L["H_TIME"] = "死亡时间"
    L["CLICK_TOGGLE"] = "左键点击: 开启/关闭面板\n左键拖动: 改变图标位置"
else
    L["TITLE"] = "Turtle Death Log (TDL v1.4.0)"
    L["NAME_SEARCH"] = "Player Name"
    L["MIN_LVL"] = "Min"
    L["MAX_LVL"] = "Max"
    L["ZONE"] = "Zone / Killer"
    L["BTN_SEARCH"] = "Search"
    L["BTN_SYNC"] = "Sync"
    L["BTN_OLDER"] = "Load Older"
    L["BTN_RECENT"] = "Last 7 Days"
    L["BTN_FIX"] = "Cleanse DB"
    L["BTN_BUG"] = "Custom Death"
    L["BTN_START"] = "Turn on Plugin"
    L["BTN_ON"] = "Plugin is ON"
    L["JOIN_DESC"] = "Data Sharing Protocol:"
    L["LOCK_WARNING"] = "Knowledge requires sacrifice.\n\nPlease click [Turn on Plugin] below\nto share your data and unlock the query feature!"
    L["H_NAME"] = "Name"
    L["H_LVL"] = "Lvl"
    L["H_ZONE"] = "Location"
    L["H_CAUSE"] = "Cause of Death"
    L["H_TIME"] = "Time"
    L["CLICK_TOGGLE"] = "Left Click: Toggle panel\nDrag: Move icon"
end

TDL_ViewAllHistory = false
if TDL_UI_Unlocked == nil then TDL_UI_Unlocked = false end 

TDL_MainFrame = CreateFrame("Frame", "TDL_MainFrame", UIParent)
TDL_MainFrame:SetWidth(760)
TDL_MainFrame:SetHeight(450)
TDL_MainFrame:SetPoint("CENTER", 0, 0)
TDL_MainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
TDL_MainFrame:EnableMouse(true)
TDL_MainFrame:SetMovable(true)
TDL_MainFrame:RegisterForDrag("LeftButton")
TDL_MainFrame:SetScript("OnDragStart", function() this:StartMoving() end)
TDL_MainFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
TDL_MainFrame:SetFrameStrata("DIALOG")
TDL_MainFrame:Hide() 

local title = TDL_MainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
title:SetPoint("TOP", 0, -18)
title:SetText(L["TITLE"])

local closeBtn = CreateFrame("Button", nil, TDL_MainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -5, -5)

local function CreateFilterEditBox(name, parent, width, labelText, x, y)
    local eb = CreateFrame("EditBox", name, parent)
    eb:SetWidth(width)
    eb:SetHeight(20)
    eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    eb:SetFontObject(ChatFontNormal)
    eb:SetAutoFocus(false)
    eb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    eb:SetBackdropColor(0, 0, 0, 0.8)
    eb:SetTextInsets(5, 5, 0, 0)
    eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function() this:ClearFocus() TDL_UpdateList() end)
    local label = eb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", eb, "TOPLEFT", 3, 2)
    label:SetText(labelText)
    return eb
end

-- 重新计算横向排版，为“玩家姓名”腾出空间
local startX, gap = 20, 10
local x1 = startX
local x2 = x1 + 80 + gap   -- Name (80)
local x3 = x2 + 40 + gap   -- MinLvl (40)
local x4 = x3 + 40 + gap   -- MaxLvl (40)
local x5 = x4 + 110 + gap  -- Zone (110)
local x6 = x5 + 60 + gap   -- Search (60)
local x7 = x6 + 65 + gap   -- Sync (65)
local x8 = x7 + 85 + gap   -- Older (85)
local x9 = x8 + 75 + gap   -- Fix (75)
-- BugBtn is at x9 (Width 85)

TDL_NameEB     = CreateFilterEditBox("TDL_NameEB", TDL_MainFrame, 80, L["NAME_SEARCH"], x1, -65)
TDL_MinLevelEB = CreateFilterEditBox("TDL_MinLevelEB", TDL_MainFrame, 40, L["MIN_LVL"], x2, -65)
TDL_MaxLevelEB = CreateFilterEditBox("TDL_MaxLevelEB", TDL_MainFrame, 40, L["MAX_LVL"], x3, -65)
TDL_ZoneEB     = CreateFilterEditBox("TDL_ZoneEB", TDL_MainFrame, 110, L["ZONE"], x4, -65)

local searchBtn = CreateFrame("Button", "TDL_SearchButton", TDL_MainFrame, "UIPanelButtonTemplate")
searchBtn:SetWidth(60); searchBtn:SetHeight(22); searchBtn:SetPoint("TOPLEFT", TDL_MainFrame, "TOPLEFT", x5, -64)
searchBtn:SetText(L["BTN_SEARCH"]); searchBtn:SetScript("OnClick", function() TDL_UpdateList() end)

local syncBtn = CreateFrame("Button", "TDL_SyncButton", TDL_MainFrame, "UIPanelButtonTemplate")
syncBtn:SetWidth(65); syncBtn:SetHeight(22); syncBtn:SetPoint("TOPLEFT", TDL_MainFrame, "TOPLEFT", x6, -64)
syncBtn:SetText(L["BTN_SYNC"])
syncBtn:SetScript("OnClick", function()
    if TDL_RequestSync then TDL_RequestSync() else DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[TDL-Error]|r 核心模块未加载！") end
    TDL_UpdateList()
end)

local olderBtn = CreateFrame("Button", "TDL_OlderButton", TDL_MainFrame, "UIPanelButtonTemplate")
olderBtn:SetWidth(85); olderBtn:SetHeight(22); olderBtn:SetPoint("TOPLEFT", TDL_MainFrame, "TOPLEFT", x7, -64)
olderBtn:SetText(L["BTN_OLDER"])
olderBtn:SetScript("OnClick", function()
    TDL_ViewAllHistory = not TDL_ViewAllHistory
    if TDL_ViewAllHistory then
        this:SetText(L["BTN_RECENT"])
        DEFAULT_CHAT_FRAME:AddMessage(GetLocale() == "zhCN" and "|cff00ff00[TDL]|r 正在为您拉取全部历史死亡数据..." or "|cff00ff00[TDL]|r Loading historical databases...")
    else
        this:SetText(L["BTN_OLDER"])
        DEFAULT_CHAT_FRAME:AddMessage(GetLocale() == "zhCN" and "|cff00ff00[TDL]|r 已切回显示最近7天数据。" or "|cff00ff00[TDL]|r Showing recent 7 days.")
    end
    TDL_UpdateList()
end)

local fixBtn = CreateFrame("Button", "TDL_FixButton", TDL_MainFrame, "UIPanelButtonTemplate")
fixBtn:SetWidth(75); fixBtn:SetHeight(22); fixBtn:SetPoint("TOPLEFT", TDL_MainFrame, "TOPLEFT", x8, -64)
fixBtn:SetText(L["BTN_FIX"]); fixBtn:SetScript("OnClick", function() if SlashCmdList["TURTLEDEATHLOG"] then SlashCmdList["TURTLEDEATHLOG"]("fix") end end)

local bugBtn = CreateFrame("Button", "TDL_BugButton", TDL_MainFrame, "UIPanelButtonTemplate")
bugBtn:SetWidth(85); bugBtn:SetHeight(22); bugBtn:SetPoint("TOPLEFT", TDL_MainFrame, "TOPLEFT", x9, -64)
bugBtn:SetText(L["BTN_BUG"]); bugBtn:SetScript("OnClick", function() StaticPopup_Show("TDL_CONFIRM_BUG_DEATH") end)

local toggleBtn = CreateFrame("Button", "TDL_ToggleBtn", TDL_MainFrame, "UIPanelButtonTemplate")
toggleBtn:SetWidth(100); toggleBtn:SetHeight(22); toggleBtn:SetPoint("BOTTOMRIGHT", TDL_MainFrame, "BOTTOMRIGHT", -25, 20)
toggleBtn:SetScript("OnClick", function()
    TDL_UI_Unlocked = true
    this:SetText(L["BTN_ON"]); this:Disable() 
    local id = GetChannelName("tdl_sync_channel_v1")
    if id == 0 then JoinChannelByName("tdl_sync_channel_v1", "tdl_hardcore", nil) end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TDL]|r " .. (GetLocale() == "zhCN" and "感谢您的共享精神，查询功能已完全解锁！" or "Thank you for sharing! Query unlocked."))
    TDL_UpdateList()
end)

local joinDesc = TDL_MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
joinDesc:SetPoint("RIGHT", toggleBtn, "LEFT", -10, 0); joinDesc:SetText(L["JOIN_DESC"]); joinDesc:SetTextColor(0.9, 0.8, 0.4) 

local lockWarning = TDL_MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
lockWarning:SetPoint("CENTER", TDL_MainFrame, "CENTER", 0, -30); lockWarning:SetText(L["LOCK_WARNING"]); lockWarning:SetJustifyH("CENTER"); lockWarning:SetTextColor(1, 0.2, 0.2); lockWarning:Hide()
TDL_LockWarningText = lockWarning

TDL_MainFrame:SetScript("OnShow", function()
    if TDL_UI_Unlocked then TDL_ToggleBtn:SetText(L["BTN_ON"]); TDL_ToggleBtn:Disable() else TDL_ToggleBtn:SetText(L["BTN_START"]); TDL_ToggleBtn:Enable() end
    if TDL_UpdateList then TDL_UpdateList() end
end)

StaticPopupDialogs["TDL_CONFIRM_BUG_DEATH"] = {
    text = (GetLocale() == "zhCN") and "确定向全网发送您的 报告另类死亡 记录吗？\n(操作将记录当前状态，请谨慎使用)" or "Report alternative death to network?",
    button1 = YES, button2 = NO,
    OnAccept = function()
        local name, lvl = UnitName("player"), UnitLevel("player")
        local zone = GetZoneText() or "Unknown Zone"
        local killer = "Custom Cause" 
        local timeStr = TDL_GetServerTimeStr and TDL_GetServerTimeStr() or date("%Y-%m-%d %H:%M")
        local deathData = name.."#"..lvl.."#"..zone.."#"..killer.."#"..timeStr
        local m = date("%Y-%m")
        if type(TDL_HistoryDB[m]) ~= "table" then TDL_HistoryDB[m] = {} end
        table.insert(TDL_HistoryDB[m], deathData)
        if TDL_RequestSync then table.insert(TDL_SendQueue, "TDL_DEATH:"..m.."^"..deathData) end
        TDL_UpdateList()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local columns = {
    { text = L["H_NAME"],  x = 30 }, { text = L["H_LVL"],   x = 135 },
    { text = L["H_ZONE"],  x = 180 }, { text = L["H_CAUSE"], x = 360 }, { text = L["H_TIME"],  x = 560 }
}
for _, col in ipairs(columns) do
    local h = TDL_MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h:SetPoint("TOPLEFT", TDL_MainFrame, "TOPLEFT", col.x, -110)
    h:SetText(col.text)
end

local scrollFrame = CreateFrame("ScrollFrame", "TDL_ScrollFrame", TDL_MainFrame, "FauxScrollFrameTemplate")
scrollFrame:SetWidth(690)
scrollFrame:SetHeight(240)
scrollFrame:SetPoint("TOPLEFT", TDL_MainFrame, "TOPLEFT", 20, -130)
scrollFrame:SetScript("OnVerticalScroll", function()
    FauxScrollFrame_OnVerticalScroll(24, TDL_UpdateList)
end)

for i = 1, 10 do
    local row = CreateFrame("Frame", "TDL_DataRow"..i, TDL_MainFrame)
    row:SetWidth(700); row:SetHeight(24); row:SetPoint("TOPLEFT", TDL_MainFrame, "TOPLEFT", 20, -108 - (i * 24))
    
    row.name   = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.level  = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.zone   = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.killer = row:CreateFontString(nil, "OVERLAY", "GameFontRedSmall") 
    row.time   = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

    row.name:SetWidth(95); row.name:SetJustifyH("LEFT")
    row.level:SetWidth(35); row.level:SetJustifyH("CENTER")
    row.zone:SetWidth(170); row.zone:SetJustifyH("LEFT")
    row.killer:SetWidth(190); row.killer:SetJustifyH("LEFT")
    row.time:SetWidth(120); row.time:SetJustifyH("RIGHT")

    row.name:SetPoint("LEFT", row, "LEFT", 10, 0)
    row.level:SetPoint("LEFT", row.name, "RIGHT", 5, 0)
    row.zone:SetPoint("LEFT", row.level, "RIGHT", 10, 0)
    row.killer:SetPoint("LEFT", row.zone, "RIGHT", 10, 0)
    row.time:SetPoint("LEFT", row.killer, "RIGHT", 10, 0)
    row:Hide()
end

local function SafeLower(str)
    if type(str) ~= "string" then return "" end
    local res = ""
    for i = 1, string.len(str) do
        local b = string.byte(str, i)
        if b >= 65 and b <= 90 then res = res .. string.char(b + 32) else res = res .. string.char(b) end
    end
    return res
end
local function CleanInput(eb) return SafeLower(string.gsub(eb:GetText() or "", "^%s*(.-)%s*$", "%1")) end

local function GetAbsoluteDay(dateStr)
    if type(dateStr) ~= "string" then return 0 end
    local _, _, y, m, d = string.find(dateStr, "(%d+)%-(%d+)%-(%d+)")
    if not y then return 0 end
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or not m or not d then return 0 end
    local days = y * 365 + math.floor(y/4) - math.floor(y/100) + math.floor(y/400)
    local monthDays = {31,28,31,30,31,30,31,31,30,31,30,31}
    for i = 1, m-1 do days = days + monthDays[i] end
    if m > 2 and ((math.mod(y, 4) == 0 and math.mod(y, 100) ~= 0) or math.mod(y, 400) == 0) then days = days + 1 end
    days = days + d
    return days
end

local filteredData = {}

function TDL_UpdateList()
    if not TDL_UI_Unlocked then
        for i = 1, 10 do getglobal("TDL_DataRow"..i):Hide() end
        if TDL_LockWarningText then TDL_LockWarningText:Show() end
        return
    else
        if TDL_LockWarningText then TDL_LockWarningText:Hide() end
    end

    filteredData = {}
    
    -- 获取新增的玩家姓名过滤
    local fName = CleanInput(TDL_NameEB)
    
    local minLvlStr = string.gsub(TDL_MinLevelEB:GetText() or "", "^%s*(.-)%s*$", "%1")
    local maxLvlStr = string.gsub(TDL_MaxLevelEB:GetText() or "", "^%s*(.-)%s*$", "%1")
    local minLvl, maxLvl = 1, 60
    
    local _, _, smartMin, smartMax = string.find(minLvlStr, "(%d+)%s*-%s*(%d+)")
    if smartMin and smartMax then
        minLvl, maxLvl = tonumber(smartMin), tonumber(smartMax)
    else
        local _, _, m1 = string.find(minLvlStr, "(%d+)"); if m1 then minLvl = tonumber(m1) end
        local _, _, m2 = string.find(maxLvlStr, "(%d+)"); if m2 then maxLvl = tonumber(m2) end
    end
    if minLvl > maxLvl then minLvl, maxLvl = maxLvl, minLvl end
    
    local fZone = CleanInput(TDL_ZoneEB)
    if type(TDL_HistoryDB) ~= "table" then TDL_HistoryDB = {} end
    
    local sevenDaysAgoAbs = 0
    if not TDL_ViewAllHistory then
        local currentDateStr = string.sub(TDL_GetServerTimeStr and TDL_GetServerTimeStr() or date("%Y-%m-%d"), 1, 10)
        sevenDaysAgoAbs = GetAbsoluteDay(currentDateStr) - 7
    end
    
    for month, dataArr in pairs(TDL_HistoryDB) do
        for _, dataStr in ipairs(dataArr) do
            local parts = {}
            local currentPos = 1
            while true do
                local startPos, endPos = string.find(dataStr, "#", currentPos)
                if not startPos then table.insert(parts, string.sub(dataStr, currentPos)) break end
                table.insert(parts, string.sub(dataStr, currentPos, startPos - 1))
                currentPos = endPos + 1
            end
            
            local name, lvl, rawZone, rawKiller, timeStr
            if table.getn(parts) >= 7 then
                name, lvl, rawZone, rawKiller, timeStr = parts[1], parts[2], parts[5], parts[6], parts[7]
            elseif table.getn(parts) >= 5 then
                name, lvl, rawZone, rawKiller, timeStr = parts[1], parts[2], parts[3], parts[4], parts[5]
            end
            
            if name then
                local include = true
                if not TDL_ViewAllHistory and timeStr then
                    local recordDate = string.sub(timeStr, 1, 10)
                    local recAbs = GetAbsoluteDay(recordDate)
                    if recAbs > 0 and recAbs < sevenDaysAgoAbs then include = false end
                end
                
                if include then
                    local dispZone = rawZone
                    local dispKiller = rawKiller
                    
                    if GetLocale() == "zhCN" and TDL_Translate then
                        dispZone = TDL_Translate(rawZone, "ZONE")
                        local origK = rawKiller
                        local isPvP = false
                        if string.find(string.lower(rawKiller), " %-pvp$") then
                            origK = string.sub(rawKiller, 1, string.len(rawKiller) - 5)
                            isPvP = true
                        end
                        dispKiller = TDL_Translate(origK, "NPC")
                        if dispKiller == "Custom Cause" then dispKiller = "|cffFF0000自定义死因|r" end
                        if isPvP then dispKiller = dispKiller .. " -pvp" end
                    end
                    
                    local match = true
                    -- 检查等级
                    if tonumber(lvl) < minLvl or tonumber(lvl) > maxLvl then match = false end
                    -- 检查姓名
                    if fName ~= "" and not string.find(SafeLower(name), fName, 1, true) then match = false end
                    -- 检查区域/死因
                    if fZone ~= "" and not string.find(SafeLower(dispZone), fZone, 1, true) and not string.find(SafeLower(dispKiller), fZone, 1, true) and not string.find(SafeLower(rawZone), fZone, 1, true) and not string.find(SafeLower(rawKiller), fZone, 1, true) then 
                        match = false 
                    end
                    
                    if match then table.insert(filteredData, {name, lvl, dispZone, dispKiller, timeStr}) end
                end
            end
        end
    end
    
    table.sort(filteredData, function(a, b)
        if not a or not b then return false end
        return (a[5] or "") > (b[5] or "") 
    end)
    
    local numResults = table.getn(filteredData)
    FauxScrollFrame_Update(TDL_ScrollFrame, numResults, 10, 24)
    local offset = FauxScrollFrame_GetOffset(TDL_ScrollFrame)
    
    for i = 1, 10 do
        local row = getglobal("TDL_DataRow"..i)
        local dataIndex = offset + i
        if dataIndex <= numResults then
            local data = filteredData[dataIndex]
            row.name:SetText(data[1] or "")
            row.level:SetText(data[2] or "")
            row.zone:SetText(data[3] or "")
            row.killer:SetText(data[4] or "")
            row.time:SetText(data[5] or "")
            row:Show()
        else row:Hide() end
    end
end

TDL_MinimapButton = CreateFrame("Button", "TDL_MinimapButton", Minimap)
TDL_MinimapButton:SetWidth(33); TDL_MinimapButton:SetHeight(33); TDL_MinimapButton:SetFrameStrata("MEDIUM"); TDL_MinimapButton:SetMovable(true)
TDL_MinimapButton:SetNormalTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
local nt = TDL_MinimapButton:GetNormalTexture()
if nt then nt:SetTexCoord(0.75, 1, 0.25, 0.5); nt:ClearAllPoints(); nt:SetWidth(21); nt:SetHeight(21); nt:SetPoint("CENTER", TDL_MinimapButton, "CENTER", 0, 0) end
local icon = TDL_MinimapButton:CreateTexture("TDL_MinimapButtonIcon", "BACKGROUND")
icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons"); icon:SetTexCoord(0.75, 1, 0.25, 0.5); icon:SetWidth(21); icon:SetHeight(21); icon:SetPoint("CENTER", TDL_MinimapButton, "CENTER", 0, 0)
local border = TDL_MinimapButton:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); border:SetWidth(56); border:SetHeight(56); border:SetPoint("TOPLEFT", TDL_MinimapButton, "TOPLEFT", 0, 0)
TDL_MinimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

if not TDL_MinimapAngle then TDL_MinimapAngle = 45 end
local function TDL_MinimapButton_UpdatePosition()
    local angle = math.rad(TDL_MinimapAngle)
    TDL_MinimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * math.cos(angle)), (80 * math.sin(angle)) - 52)
end

TDL_MinimapButton:RegisterForDrag("LeftButton")
TDL_MinimapButton:SetScript("OnDragStart", function() 
    this:LockHighlight() 
    this:SetScript("OnUpdate", function()
        local x, y = GetCursorPosition() 
        local s = Minimap:GetEffectiveScale()
        TDL_MinimapAngle = math.deg(math.atan2((y/s)-Minimap:GetBottom()-70, Minimap:GetLeft()-(x/s)+70))
        if TDL_MinimapAngle < 0 then TDL_MinimapAngle = TDL_MinimapAngle + 360 end
        TDL_MinimapButton_UpdatePosition()
    end) 
end)

TDL_MinimapButton:SetScript("OnDragStop", function() this:UnlockHighlight() this:SetScript("OnUpdate", nil) end)
TDL_MinimapButton_UpdatePosition()

TDL_MinimapButton:SetScript("OnEnter", function() 
    GameTooltip:SetOwner(this, "ANCHOR_LEFT") 
    GameTooltip:SetText("Turtle Death Log") 
    GameTooltip:AddLine(L["CLICK_TOGGLE"], 1, 1, 1) 
    GameTooltip:Show() 
end)
TDL_MinimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
TDL_MinimapButton:SetScript("OnClick", function() if TDL_MainFrame:IsVisible() then TDL_MainFrame:Hide() else TDL_MainFrame:Show(); TDL_UpdateList() end end)

-- ==========================================================
-- Core.lua - Turtle Death Log (3.0.3)
-- ==========================================================
TDL_HistoryDB = TDL_HistoryDB or {}
TDL_SendQueue = {}
TDL_PendingSyncQueue = {}
TDL_ActiveUsers = {}
TDL_ServerTimeOffset = nil 

local SYNC_CHANNEL = "tdl_sync_channel_v1"
local SYNC_PASSWORD = "tdl_hardcore"
local PREFIX_DEATH = "TDL_DEATH:"

local function SplitString(s, p)
    local rt = {}
    string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end)
    return rt
end

local dbRepaired = false
local function TDL_RepairDB()
    if dbRepaired then return end
    if type(TDL_HistoryDB) ~= "table" then TDL_HistoryDB = {} end
    local rescuedDB = {}
    local changed = false
    for k, v in pairs(TDL_HistoryDB) do
        if type(k) == "number" and type(v) == "string" then
            changed = true
            local p = SplitString(v, "#")
            if table.getn(p) >= 5 then
                local m = string.sub(p[5], 1, 7)
                if not rescuedDB[m] then rescuedDB[m] = {} end
                table.insert(rescuedDB[m], v)
            end
        elseif type(v) == "table" then
            rescuedDB[k] = v
        end
    end
    if changed then 
        TDL_HistoryDB = rescuedDB 
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TDL]|r 发现历史错乱数据，已在底层自动为您重组修复完毕！")
    end
    dbRepaired = true
end

local TDL_Reverse_Zone, TDL_Reverse_NPC
local function InitReverseDicts()
    if TDL_Reverse_Zone then return end
    TDL_Reverse_Zone = {}
    TDL_Reverse_NPC = {}
    if TDL_ZoneDict then for k, v in pairs(TDL_ZoneDict) do TDL_Reverse_Zone[v] = k end end
    if TDL_NPCDict then for k, v in pairs(TDL_NPCDict) do TDL_Reverse_NPC[v] = k end end
    if TDL_TempZoneDict then for k, v in pairs(TDL_TempZoneDict) do TDL_Reverse_Zone[v] = k end end
    if TDL_TempNPCDict then for k, v in pairs(TDL_TempNPCDict) do TDL_Reverse_NPC[v] = k end end
    if TDL_PvP_NPC_Dict then for k, v in pairs(TDL_PvP_NPC_Dict) do TDL_Reverse_NPC[v] = k end end
end

function TDL_GetEnglish(cnText)
    if not cnText or cnText == "" then return cnText end
    InitReverseDicts()
    local cleanText = string.gsub(cnText, "^%s*(.-)%s*$", "%1")
    if TDL_Reverse_Zone and TDL_Reverse_Zone[cleanText] then return TDL_Reverse_Zone[cleanText] end
    if TDL_Reverse_NPC and TDL_Reverse_NPC[cleanText] then return TDL_Reverse_NPC[cleanText] end
    return cleanText
end

function TDL_Translate(enText)
    if not enText or enText == "" then return enText end
    local cleanText = string.gsub(enText, "^%s*(.-)%s*$", "%1")
    if TDL_ZoneDict and TDL_ZoneDict[cleanText] then return TDL_ZoneDict[cleanText] end
    if TDL_NPCDict and TDL_NPCDict[cleanText] then return TDL_NPCDict[cleanText] end
    if TDL_TempZoneDict and TDL_TempZoneDict[cleanText] then return TDL_TempZoneDict[cleanText] end
    if TDL_TempNPCDict and TDL_TempNPCDict[cleanText] then return TDL_TempNPCDict[cleanText] end
    if TDL_PvP_NPC_Dict and TDL_PvP_NPC_Dict[cleanText] then return TDL_PvP_NPC_Dict[cleanText] end
    
    local lowerText = string.lower(cleanText)
    local allDicts = {TDL_ZoneDict, TDL_NPCDict, TDL_TempZoneDict, TDL_TempNPCDict, TDL_PvP_NPC_Dict}
    for _, dict in ipairs(allDicts) do
        if type(dict) == "table" then
            for k, v in pairs(dict) do
                if string.lower(k) == lowerText then return v end
            end
        end
    end
    return cleanText
end

function TDL_GetServerTimeStr()
    return date("%Y-%m-%d %H:%M")
end

local function ConvertToUTCSeconds(dateStr)
    local _, _, y, m, d, h, min = string.find(dateStr or "", "(%d+)%-(%d+)%-(%d+)%s+(%d+)%:(%d+)")
    if not y then return time() end
    local localSecs = time({year=tonumber(y), month=tonumber(m), day=tonumber(d), hour=tonumber(h), min=tonumber(min), sec=0})
    if TDL_ServerTimeOffset then return localSecs + TDL_ServerTimeOffset end
    return localSecs
end

-- =========================================================
-- 【无脑入库引擎】先记录，不轻易去重
-- =========================================================
local function InsertRecord(name, lvl, zone, killer, timeStr, isFromNetwork)
    TDL_RepairDB()
    local month = string.sub(timeStr, 1, 7)
    if not TDL_HistoryDB[month] then TDL_HistoryDB[month] = {} end
    
    for _, entry in ipairs(TDL_HistoryDB[month]) do
        local p = SplitString(entry, "#")
        if p[1] == name and p[2] == lvl and p[3] == zone and p[4] == killer and p[5] == timeStr then
            return false, nil
        end
    end
    
    local mySource = isFromNetwork and "net" or "local"
    local record = name.."#"..lvl.."#"..zone.."#"..killer.."#"..timeStr.."#"..mySource
    local broadcastData = name.."#"..lvl.."#"..zone.."#"..killer.."#"..timeStr
    
    table.insert(TDL_HistoryDB[month], record)
    return true, broadcastData
end

local function GetDeathName(str)
    local _, _, m = string.find(str, "玩家%s*(.-)%s*在") if m then return m end
    _, _, m = string.find(str, "角色%s*(.-)%s*%(等级") if m then return m end
    _, _, m = string.find(str, "角色%s*(.-)%s*（等级") if m then return m end
    _, _, m = string.find(str, "玩家%s*(.-)%s*%(等级") if m then return m end
    _, _, m = string.find(str, "玩家%s*(.-)%s*（等级") if m then return m end
    _, _, m = string.find(str, "character%s+(.-)%s*%(level") if m then return m end
    _, _, m = string.find(str, "Character%s+(.-)%s*%(level") if m then return m end
    _, _, _, m = string.find(str, "Level%s+(%d+)%s+%S+%s+(.-)%s+has") if m then return m end
    _, _, m = string.find(str, "%[HC%]%s*(.-)%s*在") if m then return m end
    return nil
end

local function GetDeathLevel(str)
    local _, _, m = string.find(str, "享年%s*(%d+)") if m then return m end
    _, _, m = string.find(str, "level%s*(%d+)%)%s*has") if m then return m end
    _, _, m = string.find(str, "等级%s*(%d+)%)%s*被") if m then return m end
    _, _, m = string.find(str, "等级%s*(%d+)）%s*被") if m then return m end
    _, _, m = string.find(str, "等级%s*(%d+)%)%s*.-这发生在") if m then return m end
    _, _, m = string.find(str, "等级%s*(%d+)）%s*.-这发生在") if m then return m end
    _, _, m = string.find(str, "Level%s*(%d+)%s+%S+") if m then return m end
    for num in string.gfind(str, "(%d+)") do m = num end
    return m
end

local function GetDeathZone(str)
    local _, _, m = string.find(str, "这发生在%s*(.-)。") if m then return m end
    _, _, m = string.find(str, "这发生在%s*(.*)") if m then return m end
    _, _, m = string.find(str, "在%s*(.-)%s*被") if m then return m end
    for _, kw in ipairs({"摔死", "溺水", "淹死", "岩浆", "烧死", "跌死", "死亡", "击杀"}) do
        local _, _, tempZ = string.find(str, "在%s*(.-)%s*"..kw)
        if tempZ then return tempZ end
    end
    _, _, m = string.find(str, "in%s+(.-)%.%s*May this") if m then return m end
    _, _, m = string.find(str, "in%s+(.-)%.") if m then return m end
    return m
end

local function GetDeathKiller(str)
    local _, _, m = string.find(str, "被%s*(.-)%s*击杀") if m then return m end
    _, _, m = string.find(str, "fallen to%s+(.-)%s+in") if m then return m end
    _, _, m = string.find(str, "killed by%s+(.-)%s+in") if m then return m end
    _, _, m = string.find(str, "Killed by%s+(.-)%.") if m then return m end
    for _, kw in ipairs({"摔死", "溺水", "淹死", "岩浆", "烧死", "跌死"}) do
        if string.find(str, kw) then return "Environment" end
    end
    if string.find(str, "has died in") or string.find(str, "died in") then return "Environment" end
    return nil
end

local function ParseDeathMessage(msg)
    if type(msg) ~= "string" then return nil end
    local t = string.gsub(msg, "|c%x%x%x%x%x%x%x%x", "")
    -- 【核心修复2】：剥离聊天链接时，强制粉碎隐藏的方括号，防止污染名字提取
    t = string.gsub(t, "|H.-|h%[(.-)%]|h", "%1") 
    t = string.gsub(t, "|H.-|h(.-)|h", "%1")
    t = string.gsub(t, "|r", "")
    
    local upperT = string.upper(t) 
    local hasIdentity = string.find(upperT, "%[HC%]") or string.find(t, "硬核") or string.find(upperT, "HARDCORE")
    local hasDeathAction = string.find(t, "击杀") or string.find(t, "悲剧发生") or string.find(t, "摔死") or 
                           string.find(t, "溺水") or string.find(t, "淹死") or string.find(t, "岩浆") or 
                           string.find(t, "烧死") or string.find(t, "跌死") or string.find(t, "死亡") or 
                           string.find(t, "has fallen") or string.find(t, "has died") or 
                           string.find(t, "killed by") or string.find(t, "died in") or
                           string.find(t, "tragedy has occurred")

    if not (hasIdentity and hasDeathAction) then
        if not (string.find(t, "has fallen") or string.find(t, "has died")) then return nil end
    end

    local name = GetDeathName(t)
    local lvl = GetDeathLevel(t)
    local zone = GetDeathZone(t)
    local killer =

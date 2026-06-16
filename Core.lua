-- ==========================================================
-- Core.lua - Turtle Death Log (3.0.1 先记录后整理分离版)
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
-- 【核心重构：无脑入库引擎】不管是否有重复，只要不是网络回音，直接记录！
-- =========================================================
local function InsertRecord(name, lvl, zone, killer, timeStr, isFromNetwork)
    TDL_RepairDB()
    local month = string.sub(timeStr, 1, 7)
    if not TDL_HistoryDB[month] then TDL_HistoryDB[month] = {} end
    
    -- 仅仅做最基础的“完全一模一样”拦截，防止网络频道死循环复读
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
    local _, _, m = string.find(str, "玩家%s*([^%s在]+)%s*在") if m then return m end
    _, _, m = string.find(str, "角色%s*([^%s%(（]+)%s*[%(（]等级") if m then return m end
    _, _, m = string.find(str, "玩家%s*([^%s%(（]+)%s*[%(（]等级") if m then return m end
    _, _, m = string.find(str, "character%s+([^%s%(]+)%s*%(level") if m then return m end
    _, _, m = string.find(str, "Character%s+([^%s%(]+)%s*%(level") if m then return m end
    _, _, _, m = string.find(str, "Level%s+(%d+)%s+%S+%s+([^%s]+)%s+has") if m then return m end
    _, _, m = string.find(str, "%[HC%]%s*([^%s在]+)%s*在") if m then return m end
    return nil
end

local function GetDeathLevel(str)
    local _, _, m = string.find(str, "享年%s*(%d+)") if m then return m end
    _, _, m = string.find(str, "level%s*(%d+)%)%s*has") if m then return m end
    _, _, m = string.find(str, "等级%s*(%d+)%)%s*被") if m then return m end
    _, _, m = string.find(str, "等级%s*(%d+)%)%s*.-这发生在") if m then return m end
    _, _, m = string.find(str, "Level%s*(%d+)%s+%S+") if m then return m end
    for num in string.gfind(str, "(%d+)") do m = num end
    return m
end

local function GetDeathZone(str)
    local _, _, m = string.find(str, "这发生在%s*([^。%.]+)") if m then return m end
    _, _, m = string.find(str, "在%s*(.-)%s*被") if m then return m end
    for _, kw in ipairs({"摔死", "溺水", "淹死", "岩浆", "烧死", "跌死", "死亡", "击杀"}) do
        local _, _, tempZ = string.find(str, "在%s*(.-)%s*"..kw)
        if tempZ then return tempZ end
    end
    _, _, m = string.find(str, "in%s+([^%.]+)%.%s*May this") if m then return m end
    _, _, m = string.find(str, "in%s+([^%.]+)%.")
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
    local killer = GetDeathKiller(t)

    if string.find(upperT, "PVP") and killer == "Environment" then killer = "PvP Death" end

    if name and name ~= "" and lvl then
        zone = zone or "Unknown Zone"
        killer = killer or "Environment"
        
        name = string.gsub(name, "%[.-%]", "")
        name = string.gsub(name, "硬核角色", "")
        name = string.gsub(name, "硬核玩家", "")
        name = string.gsub(name, "硬核", "")
        name = string.gsub(name, "玩家", "")
        name = string.gsub(name, "Hardcore", "")
        name = string.gsub(name, "^%s*(.-)%s*$", "%1") 
        
        killer = string.gsub(killer, "^%d+级玩家%s*", "")
        killer = string.gsub(killer, "^%d+级%s*", "")
        killer = string.gsub(killer, "玩家", "")
        killer = string.gsub(killer, "[%(（]等级.-[%)）]", "")
        killer = string.gsub(killer, "%(level.-%)", "")
        killer = string.gsub(killer, "[。，！!%.]+$", "")
        killer = string.gsub(killer, "^%s*(.-)%s*$", "%1")
        
        zone = string.gsub(zone, "愿这一牺牲不会被遗忘", "")
        zone = string.gsub(zone, "May this sacrifice not be forgotten", "")
        zone = string.gsub(zone, "[。，！!%.]+$", "")
        zone = string.gsub(zone, "^%s*(.-)%s*$", "%1")
        
        if name == "" then return nil end
        if killer == "" then killer = "Environment" end
        if zone == "" then zone = "Unknown Zone" end
        
        return name, lvl, killer, zone
    end
    return nil
end

local coreFrame = CreateFrame("Frame")
coreFrame:RegisterEvent("CHAT_MSG_SYSTEM")
coreFrame:RegisterEvent("CHAT_MSG_BROADCAST")
coreFrame:RegisterEvent("CHAT_MSG_SERVER_EMOTE")
coreFrame:RegisterEvent("CHAT_MSG_INFO")
coreFrame:RegisterEvent("CHAT_MSG_CHANNEL")
coreFrame:RegisterEvent("CHAT_MSG_YELL")
coreFrame:RegisterEvent("CHAT_MSG_MONSTER_YELL")
coreFrame:RegisterEvent("CHAT_MSG_GUILD")
coreFrame:RegisterEvent("CHAT_MSG_SAY")

coreFrame:SetScript("OnEvent", function()
    TDL_RepairDB()
    if event == "CHAT_MSG_SYSTEM" then
        if string.find(arg1, "服务器时间") or string.find(string.lower(arg1), "server time") then
            local _, _, d, m, y, h, min, s = string.find(arg1, "(%d+)%.(%d+)%.(%d+)%s+(%d+)%D+(%d+)%D+(%d+)")
            if y and m and d and h and min and s then
                local srvTime = time({year=tonumber(y), month=tonumber(m), day=tonumber(d), hour=tonumber(h), min=tonumber(min), sec=tonumber(s)})
                TDL_ServerTimeOffset = srvTime - time()
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TDL]|r 收到服务器时间！时钟对齐完毕。")
            end
        end
    end

    if event == "CHAT_MSG_CHANNEL" then
        local channelName = arg9 and string.lower(arg9) or ""
        if string.find(channelName, "tdl_sync_channel") then
            if arg2 ~= UnitName("player") then
                if string.find(arg1, "^" .. PREFIX_DEATH) then
                    local payload = string.sub(arg1, string.len(PREFIX_DEATH) + 1)
                    local _, _, _, dataStr = string.find(payload, "^(.-)%^(.*)")
                    if dataStr then
                        local p = SplitString(dataStr, "#")
                        if table.getn(p) >= 5 then
                            local isUpdated, broadcastData = InsertRecord(p[1], p[2], p[3], p[4], p[5], true)
                            if isUpdated and broadcastData then
                                local cM = string.sub(p[5], 1, 7)
                                table.insert(TDL_SendQueue, PREFIX_DEATH .. cM .. "^" .. broadcastData)
                                if TDL_MainFrame and TDL_MainFrame:IsVisible() and TDL_UpdateList then TDL_UpdateList() end
                            end
                        end
                    end
                elseif string.find(arg1, "^TDL_REQ_SYNC") then
                    for m, records in pairs(TDL_HistoryDB) do
                        if type(records) == "table" then
                            for _, rec in ipairs(records) do
                                local p = SplitString(rec, "#")
                                if table.getn(p) >= 5 then
                                    local pureData = p[1].."#"..p[2].."#"..p[3].."#"..p[4].."#"..p[5]
                                    table.insert(TDL_SendQueue, PREFIX_DEATH .. m .. "^" .. pureData)
                                end
                            end
                        end
                    end
                end
            end
            return 
        end
    end

    local name, level, killer, zone = ParseDeathMessage(arg1)
    if name then
        local timeStr = TDL_GetServerTimeStr()
        if GetLocale() == "zhCN" then
            zone = TDL_GetEnglish(zone)
            local isPvP = string.find(string.lower(killer), "%-pvp$")
            if isPvP then killer = string.sub(killer, 1, string.len(killer) - 5) end
            killer = TDL_GetEnglish(killer)
            if isPvP then killer = killer .. " -pvp" end
        end
        local isNew, broadcastData = InsertRecord(name, level, zone, killer, timeStr)
        if isNew and broadcastData then
            local cM = string.sub(timeStr, 1, 7)
            table.insert(TDL_SendQueue, PREFIX_DEATH .. cM .. "^" .. broadcastData)
            if TDL_MainFrame and TDL_MainFrame:IsVisible() and TDL_UpdateList then TDL_UpdateList() end
        end
    end
end)

local tickFrame = CreateFrame("Frame")
local elapsed = 0
local isJoined = false

local manualTasks = {}
local manualTaskTimer = 0.0

tickFrame:SetScript("OnUpdate", function()
    local dt = arg1 or 0.05
    
    if table.getn(manualTasks) > 0 then
        manualTaskTimer = manualTaskTimer - dt
        if manualTaskTimer <= 0 then
            local task = table.remove(manualTasks, 1)
            manualTaskTimer = 3.0  
            task()
        end
    end

    elapsed = elapsed + dt
    if elapsed > 7.0 then
        elapsed = 0
        local id = GetChannelName(SYNC_CHANNEL)
        if id == 0 and not isJoined then
            JoinChannelByName(SYNC_CHANNEL, SYNC_PASSWORD)
            isJoined = true
        end
        if table.getn(TDL_SendQueue) > 0 and id > 0 then
            local msg = table.remove(TDL_SendQueue, 1)
            SendChatMessage(msg, "CHANNEL", nil, id)
        end
    end
end)

-- =========================================================
-- 【核心重构：整理命令专属去重】严格按：名字、地点、时间±1天 进行清洗
-- =========================================================
function TDL_CleanDatabase(quiet, fromSync)
    TDL_RepairDB()
    local oldDB = TDL_HistoryDB
    local totalOld, totalNew = 0, 0
    TDL_HistoryDB = {}
    
    for m, records in pairs(oldDB) do
        if type(records) == "table" then
            for _, rec in ipairs(records) do
                totalOld = totalOld + 1
                local p = SplitString(rec, "#")
                if table.getn(p) >= 5 then 
                    local name, lvl, zone, killer, timeStr, source = p[1], p[2], p[3], p[4], p[5], p[6] or "local"
                    local month = string.sub(timeStr, 1, 7)
                    if not TDL_HistoryDB[month] then TDL_HistoryDB[month] = {} end
                    
                    local newUTC = ConvertToUTCSeconds(timeStr)
                    local merged = false
                    
                    -- 去重核心判断：名字一致 + 地点一致 + 时间误差在24小时（86400秒）内
                    for i, entry in ipairs(TDL_HistoryDB[month]) do
                        local ep = SplitString(entry, "#")
                        local eName, eLvl, eZone, eKiller, eTime, eSource = ep[1], ep[2], ep[3], ep[4], ep[5], ep[6] or "local"
                        local eUTC = ConvertToUTCSeconds(eTime)
                        
                        if eName == name and eZone == zone and math.abs(eUTC - newUTC) <= 86400 then
                            local bestKiller = eKiller
                            if (bestKiller == "Unknown" or bestKiller == "未知" or bestKiller == "Environment" or bestKiller == "") and killer and killer ~= "Unknown" and killer ~= "Environment" then bestKiller = killer end
                            
                            local bestTime = eTime
                            local bestSource = eSource
                            if eSource == "local" and source == "net" then bestTime = eTime; bestSource = "local"
                            elseif eSource == "net" and source == "local" then bestTime = timeStr; bestSource = "local"
                            else if newUTC < eUTC then bestTime = timeStr else bestTime = eTime end; bestSource = eSource end
                            
                            TDL_HistoryDB[month][i] = eName.."#"..eLvl.."#"..eZone.."#"..bestKiller.."#"..bestTime.."#"..bestSource
                            merged = true
                            break
                        end
                    end
                    
                    if not merged then
                        table.insert(TDL_HistoryDB[month], name.."#"..lvl.."#"..zone.."#"..killer.."#"..timeStr.."#"..source)
                    end
                end
            end
        end
    end
    
    for m, records in pairs(TDL_HistoryDB) do totalNew = totalNew + table.getn(records) end
    if TDL_UpdateList then TDL_UpdateList() end
    
    local optimizedCount = totalOld - totalNew
    if not quiet then 
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TDL]|r 数据库整理完毕！共依据（时间±1天、名字、地点）查重并清理了 " .. optimizedCount .. " 条冗余数据。") 
    end
end

local lastReq = 0
function TDL_RequestSync()
    local now = GetTime()
    if now - lastReq < 10 then 
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[TDL]|r 频道正在同步或冷却中，请等待！") return 
    end
    lastReq = now
    
    local id = GetChannelName(SYNC_CHANNEL)
    if id > 0 then
        SendChatMessage("TDL_REQ_SYNC", "CHANNEL", nil, id)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TDL]|r 已发送全网数据同步请求...")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[TDL-Error]|r 尚未连接到数据网络。")
    end
end

SLASH_TURTLEDEATHLOG1 = "/tdl"
SlashCmdList["TURTLEDEATHLOG"] = function(msg)
    TDL_RepairDB()
    local cmd = string.lower(msg or "")
    if cmd == "fix" then 
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[TDL]|r 收到整理指令！已启动防卡顿序列任务，请稍候...")
        manualTasks = {}
        manualTaskTimer = 3.0  
        
        table.insert(manualTasks, function()
            SendChatMessage(".s info", "SAY")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[TDL]|r (1/2) 正在向服务器查询绝对时间...")
        end)
        
        table.insert(manualTasks, function()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[TDL]|r (2/2) 时间已锁定，正在清洗本地数据...")
            TDL_CleanDatabase(false, false)
        end)
        
    elseif cmd == "clear" then
        TDL_HistoryDB = {}
        if TDL_UpdateList then TDL_UpdateList() end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TDL]|r 所有本地数据已清空。")
    elseif cmd == "minimap" then
        if TDL_MinimapButton:IsVisible() then TDL_MinimapButton:Hide() else TDL_MinimapButton:Show() end
    else
        if TDL_MainFrame:IsVisible() then TDL_MainFrame:Hide() else TDL_MainFrame:Show(); if TDL_UpdateList then TDL_UpdateList() end end
    end
end

-- ==========================================================
-- Core.lua - Turtle Death Log (V1.2.7 - 按日去重 + 24小时制智能洗数据版)
-- ==========================================================
if type(TDL_HistoryDB) ~= "table" then TDL_HistoryDB = {} end
local currentMonth = date("%Y-%m")
if type(TDL_HistoryDB[currentMonth]) ~= "table" then TDL_HistoryDB[currentMonth] = {} end

if type(TDL_Database) == "table" and table.getn(TDL_Database) > 0 then
    for _, v in ipairs(TDL_Database) do table.insert(TDL_HistoryDB[currentMonth], v) end
    TDL_Database = nil
end

local SYNC_CHANNEL = "tdl_sync_channel_v1"
local SYNC_PASSWORD = "tdl_hardcore"
local PREFIX_DEATH = "TDL_DEATH:"
local hasWarnedVer = false

if TDL_Dict_Version == nil then TDL_Dict_Version = "1.0.0" end
TDL_ForceEnglish = false

TDL_ReceiveData = {newCount = 0, totalCount = 0, timer = 0, active = false}
TDL_ActiveUsers = {}

-- ==========================================================
-- 【全新黑科技：全球统一服务器时间生成器】
-- ==========================================================
function TDL_GetServerTimeStr()
    local srvHour, srvMin = GetGameTime()
    local locTime = time()
    local d = date("*t", locTime)
    
    local hourDiff = srvHour - d.hour
    if hourDiff > 12 then
        locTime = locTime - 86400 
    elseif hourDiff < -12 then
        locTime = locTime + 86400 
    end
    
    local newD = date("*t", locTime)
    return string.format("%04d-%02d-%02d %02d:%02d", newD.year, newD.month, newD.day, srvHour, srvMin)
end

-- ==========================================================
-- 【智能发送探针】
-- ==========================================================
local isSuperWoW = false
local TDL_SendInterval = 3.5  

if SuperWoW or (getglobal("SendAddonMessage") and type(SendAddonMessage) == "function") then
    isSuperWoW = true
    TDL_SendInterval = 3.0    
end

local function GetVerNum(v)
    local _, _, a, b, c = string.find(v or "", "(%d+)%.(%d+)%.(%d+)")
    return (tonumber(a) or 0)*10000 + (tonumber(b) or 0)*100 + (tonumber(c) or 0)
end

local function GetSafeChannelID()
    local id = GetChannelName(SYNC_CHANNEL)
    if id > 0 then return id end
    
    local list = {GetChannelList()}
    for i = 1, table.getn(list) do
        if type(list[i]) == "string" and string.lower(list[i]) == SYNC_CHANNEL then
            if i > 1 and type(list[i-1]) == "number" then
                return list[i-1]
            end
        end
    end
    return 0
end

-- ==========================================================
-- 【智能去重时间处理模块】
-- ==========================================================
-- 获取精确到分钟的时间字符串
local function GetMinuteTime(tStr)
    return string.sub(tStr or "", 1, 16)
end

-- 获取纯日期字符串 (YYYY-MM-DD)，作为查重的唯一标识
local function GetDateOnly(tStr)
    return string.sub(tStr or "", 1, 10)
end

-- 智能挑选24小时制时间：强制保留小时数更大的那一个
local function GetBest24HTime(t1, t2)
    if not t1 or t1 == "" then return t2 end
    if not t2 or t2 == "" then return t1 end
    
    local _, _, h1 = string.find(t1, " (%d+):")
    local _, _, h2 = string.find(t2, " (%d+):")
    
    local hr1 = tonumber(h1) or -1
    local hr2 = tonumber(h2) or -1
    
    if hr1 > hr2 then return t1 else return t2 end
end

local function MergeBestData(z1, k1, z2, k2)
    local bestZ = z1
    local bestK = k1
    if (not bestZ or bestZ == "Unknown Zone" or bestZ == "未知区域" or bestZ == "") and z2 then bestZ = z2 end
    if (not bestK or bestK == "Environment" or bestK == "未知" or bestK == "") and k2 then bestK = k2 end
    return bestZ, bestK
end

-- ==========================================================
-- 【核心封装：数据库智能洗涤引擎】(供手动与自动调用)
-- ==========================================================
local function TDL_CleanDatabase(isAuto)
    local fixCount = 0
    local dupCount = 0
    if type(TDL_HistoryDB) == "table" then
        for month, dataArr in pairs(TDL_HistoryDB) do
            local newMonthArr = {}
            for i, dataStr in ipairs(dataArr) do
                local parts = {}
                local currentPos = 1
                while true do
                    local startPos, endPos = string.find(dataStr, "#", currentPos)
                    if not startPos then table.insert(parts, string.sub(dataStr, currentPos)) break end
                    table.insert(parts, string.sub(dataStr, currentPos, startPos - 1))
                    currentPos = endPos + 1
                end
                
                local name, lvl, zone, killer, timeStr
                if table.getn(parts) >= 7 then
                    name, lvl, zone, killer, timeStr = parts[1], parts[2], parts[5], parts[6], parts[7]
                elseif table.getn(parts) >= 5 then
                    name, lvl, zone, killer, timeStr = parts[1], parts[2], parts[3], parts[4], parts[5]
                end
                
                if name and timeStr then
                    local originalData = dataStr
                    local originalKiller = killer
                    if string.find(string.lower(killer), " %-pvp$") then
                        originalKiller = string.sub(killer, 1, string.len(killer) - 5)
                    end
                    
                    if GetLocale() == "zhCN" and TDL_Translate then
                        zone = TDL_Translate(zone, "ZONE")
                        killer = TDL_Translate(originalKiller, "NPC")
                    else
                        killer = originalKiller
                    end
                    
                    local isPvP = false
                    if TDL_PvP_NPC_Dict and (TDL_PvP_NPC_Dict[originalKiller] or TDL_PvP_NPC_Dict[killer]) then
                        isPvP = true
                    end
                    
                    if isPvP then killer = killer .. " -pvp" end
                    
                    local targetDate = GetDateOnly(timeStr)
                    local targetFullTime = GetMinuteTime(timeStr)
                    local newData = name.."#"..lvl.."#"..zone.."#"..killer.."#"..targetFullTime
                    
                    local isDup = false
                    for j, oData in ipairs(newMonthArr) do
                        local oParts = {}
                        local oPos = 1
                        while true do
                            local sPos, ePos = string.find(oData, "#", oPos)
                            if not sPos then table.insert(oParts, string.sub(oData, oPos)) break end
                            table.insert(oParts, string.sub(oData, oPos, sPos - 1))
                            oPos = ePos + 1
                        end
                        
                        local oName = oParts[1]
                        local oLvl = oParts[2]
                        local oDate = GetDateOnly(oParts[5])
                        
                        -- 【绝杀逻辑】：名字、等级、年月日一致即视为同一条数据
                        if oName == name and oLvl == lvl and oDate == targetDate then
                            isDup = true
                            local bestZ, bestK = MergeBestData(zone, killer, oParts[3], oParts[4])
                            local bestL = lvl or oLvl
                            -- 智能选择24小时制时间
                            local bestTime = GetBest24HTime(targetFullTime, GetMinuteTime(oParts[5]))
                            local mergedData = oName.."#"..bestL.."#"..bestZ.."#"..bestK.."#"..bestTime
                            
                            if newMonthArr[j] ~= mergedData then
                                newMonthArr[j] = mergedData
                                fixCount = fixCount + 1
                            else
                                dupCount = dupCount + 1
                            end
                            break
                        end
                    end
                    
                    if not isDup then
                        table.insert(newMonthArr, newData)
                        if originalData ~= newData then
                            fixCount = fixCount + 1
                        end
                    end
                end
            end
            TDL_HistoryDB[month] = newMonthArr
        end
    end
    if TDL_UpdateList then TDL_UpdateList() end
    
    if isAuto then
        if fixCount > 0 or dupCount > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[TDL-后台]|r 自动整理完毕！清洗了 " .. dupCount .. " 条冗余数据。")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TDL]|r 数据库智能整理完成！完美保留精华，清洗了 " .. dupCount .. " 条冗余重复数据。")
    end
end

local function InsertOrMergeRecord(month, dataStr)
    if type(TDL_HistoryDB[month]) ~= "table" then TDL_HistoryDB[month] = {} end
    
    local parts = {}
    local currentPos = 1
    while true do
        local startPos, endPos = string.find(dataStr, "#", currentPos)
        if not startPos then table.insert(parts, string.sub(dataStr, currentPos)) break end
        table.insert(parts, string.sub(dataStr, currentPos, startPos - 1))
        currentPos = endPos + 1
    end
    
    local name, lvl, zone, killer, timeStr = parts[1], parts[2], parts[3], parts[4], parts[5]
    if not name or not timeStr then return false end
    
    local targetDate = GetDateOnly(timeStr)
    local targetFullTime = GetMinuteTime(timeStr)
    
    for i, oldDataStr in ipairs(TDL_HistoryDB[month]) do
        local oParts = {}
        local oPos = 1
        while true do
            local sPos, ePos = string.find(oldDataStr, "#", oPos)
            if not sPos then table.insert(oParts, string.sub(oldDataStr, oPos)) break end
            table.insert(oParts, string.sub(oldDataStr, oPos, sPos - 1))
            oPos = ePos + 1
        end
        
        local oName, oLvl, oZone, oKiller, oTimeStr = oParts[1], oParts[2], oParts[3], oParts[4], oParts[5]
        
        -- 【同绝杀逻辑应用在接收入库时】
        if oName == name and oLvl == lvl and GetDateOnly(oTimeStr) == targetDate then
            local bestZone, bestKiller = MergeBestData(zone, killer, oZone, oKiller)
            local bestLvl = lvl or oLvl
            -- 智能选择24小时制时间
            local bestTime = GetBest24HTime(targetFullTime, GetMinuteTime(oTimeStr))
            local mergedData = oName.."#"..bestLvl.."#"..bestZone.."#"..bestKiller.."#"..bestTime
            
            if oldDataStr ~= mergedData then
                TDL_HistoryDB[month][i] = mergedData 
                return true
            end
            return false
        end
    end
    
    local sanitizedData = name.."#"..lvl.."#"..zone.."#"..killer.."#"..targetFullTime
    table.insert(TDL_HistoryDB[month], sanitizedData)
    return true
end

-- ==========================================================
-- 【请求冷却与发信接口】
-- ==========================================================
local TDL_LastSyncRequestTime = 0
local TDL_PostSyncCleanTimer = -1 

function TDL_RequestSync()
    local now = GetTime()
    if now - TDL_LastSyncRequestTime < 10 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[TDL-Error]|r 频道正在同步或冷却中，请勿频繁点击！(冷却10秒)")
        return
    end
    TDL_LastSyncRequestTime = now
    
    -- 激活同步后洗数据倒计时
    TDL_PostSyncCleanTimer = 120 

    local id = GetSafeChannelID()
    if id > 0 then
        SendChatMessage("TDL_REQ_SYNC", "CHANNEL", nil, id)
        SendChatMessage("TDL_VER:" .. (TDL_Dict_Version or "1.0.0"), "CHANNEL", nil, id)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[TDL-Error]|r 同步失败：尚未连接到数据网络，请等待后台自动连接。")
    end
end

local coreFrame = CreateFrame("Frame")
coreFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
coreFrame:RegisterEvent("CHAT_MSG_SYSTEM")
coreFrame:RegisterEvent("CHAT_MSG_BROADCAST")
coreFrame:RegisterEvent("CHAT_MSG_SERVER_EMOTE")
coreFrame:RegisterEvent("CHAT_MSG_INFO")
coreFrame:RegisterEvent("CHAT_MSG_CHANNEL")
coreFrame:RegisterEvent("CHAT_MSG_CHANNEL_JOIN")
coreFrame:RegisterEvent("CHAT_MSG_CHANNEL_LEAVE")

local delayFrame = CreateFrame("Frame")
local elapsed = 0
local joinTimer = 0
local TDL_IsJoinedSyncChannel = false

TDL_PendingSyncQueue = {} 
TDL_SendQueue = {}        
local TDL_SyncDelayTimer = 0 
local sendTimer = 0

local TDL_InitialCleanDone = false 

delayFrame:SetScript("OnUpdate", function()
    local dt = arg1 or 0.016
    elapsed = elapsed + dt
    
    if not TDL_InitialCleanDone and elapsed > 60 then
        TDL_InitialCleanDone = true
        TDL_CleanDatabase(true)
    end
    
    if TDL_PostSyncCleanTimer > 0 then
        TDL_PostSyncCleanTimer = TDL_PostSyncCleanTimer - dt
        if TDL_PostSyncCleanTimer <= 0 then
            TDL_CleanDatabase(true)
            TDL_PostSyncCleanTimer = -1 
        end
    end
    
    if elapsed > 15 then
        joinTimer = joinTimer + dt
        if joinTimer > 8 then
            joinTimer = 0
            local id = GetSafeChannelID()
            if id == 0 then 
                JoinChannelByName(SYNC_CHANNEL, SYNC_PASSWORD, nil) 
            else
                if not TDL_IsJoinedSyncChannel then
                    TDL_IsJoinedSyncChannel = true
                    table.insert(TDL_SendQueue, "TDL_VER:" .. (TDL_Dict_Version or "1.0.0"))
                end
            end
        end
    end

    if TDL_SyncDelayTimer > 0 then
        TDL_SyncDelayTimer = TDL_SyncDelayTimer - dt
        if TDL_SyncDelayTimer <= 0 then
            local pendingCount = table.getn(TDL_PendingSyncQueue)
            if pendingCount > 0 then
                for _, msg in ipairs(TDL_PendingSyncQueue) do
                    table.insert(TDL_SendQueue, msg)
                end
                TDL_PendingSyncQueue = {}
            end
        end
    end

    if table.getn(TDL_SendQueue) > 0 then
        sendTimer = sendTimer + dt
        if sendTimer > TDL_SendInterval then
            sendTimer = 0
            local id = GetSafeChannelID()
            if id > 0 then
                local msg = table.remove(TDL_SendQueue, 1)
                SendChatMessage(msg, "CHANNEL", nil, id)
            end
        end
    end
    
    if TDL_ReceiveData.active then
        TDL_ReceiveData.timer = TDL_ReceiveData.timer + dt
        if TDL_ReceiveData.timer > 4.5 then 
            TDL_ReceiveData.active = false
            TDL_ReceiveData.timer = 0
            TDL_ReceiveData.totalCount = 0
            TDL_ReceiveData.newCount = 0
        end
    end
end)

delayFrame:Show()

local function ParseDeathMessage(msg)
    if not msg then return nil, nil, nil, nil end
    
    if not (string.find(msg, "fallen") or string.find(msg, "died") or string.find(msg, "Killed by") or string.find(msg, "击杀") or string.find(msg, "享年") or string.find(msg, "摔死") or string.find(msg, "溺水") or string.find(msg, "淹死") or string.find(msg, "岩浆") or string.find(msg, "烧死") or string.find(msg, "跌死")) then
        return nil, nil, nil, nil
    end
    
    local cleanMsg = string.gsub(msg, "|c%x%x%x%x%x%x%x%x", "")
    cleanMsg = string.gsub(cleanMsg, "|H.-|h(.-)|h", "%1")
    cleanMsg = string.gsub(cleanMsg, "|r", "")
    
    local name, zone, killer, level
    local isPvP = false

    if string.find(cleanMsg, "fallen in PvP") or string.find(cleanMsg, "Mak'gora") or string.find(cleanMsg, "决斗") or string.find(cleanMsg, "被玩家") or string.find(cleanMsg, "级玩家") or string.find(cleanMsg, "%[PVP") then 
        isPvP = true 
    end

    if not name then _, _, name, level, killer, zone = string.find(cleanMsg, "character (.-) %(level (%d+)%) has fallen.-to (.-) %(level %d+%) in (.-)%.") end
    if not name then _, _, level, name, zone, killer = string.find(cleanMsg, "Level (%d+) %S+ (.-) has died in (.-)%. Killed by (.-)%.") end
    if not name then _, _, level, name, zone = string.find(cleanMsg, "Level (%d+) %S+ (.-) has died in (.-)%.") if name then killer = "Environment" end end

    if not name and not TDL_ForceEnglish then
        if string.find(cleanMsg, "occurred") and string.find(cleanMsg, "被.-级玩家") then _, _, killer, level, name = string.find(cleanMsg, "被(.-)级玩家(%d+)击杀.-享年(.-)级") end
        if not name then _, _, name, zone, killer, level = string.find(cleanMsg, "玩家%s*(.-)%s*在(.-)被.-级(.-)击杀.-(%d+)级") end
        if not name then _, _, name, zone, killer, level = string.find(cleanMsg, "玩家%s*(.-)%s*在(.-)被(.-)击杀.-(%d+)级") end
        if not name then _, _, level, name, zone, killer = string.find(cleanMsg, "(%d+)级.-玩家%s*(.-)%s*在(.-)被.-级(.-)击杀") end
        if not name then _, _, level, name, zone, killer = string.find(cleanMsg, "(%d+)级.-玩家%s*(.-)%s*在(.-)被(.-)击杀") end
        if not name then
            local keywords = {"摔死", "溺水", "淹死", "岩浆", "烧死", "跌死"}
            for _, kw in ipairs(keywords) do
                _, _, name, zone, level = string.find(cleanMsg, "玩家%s*(.-)%s*在(.-)"..kw..".-(%d+)级")
                if name then killer = kw break end
            end
        end
    end

    if name and killer and zone and level then
        if string.find(name, " ") or not tonumber(level) then return nil, nil, nil, nil end
        name = string.gsub(name, "^%s*(.-)%s*$", "%1")
        zone = string.gsub(zone, "^%s*(.-)%s*$", "%1")
        killer = string.gsub(killer, "^%s*(.-)%s*$", "%1")
        killer = string.gsub(killer, "[。！!，,]$", "")
        
        local originalKiller = killer
        
        if GetLocale() == "zhCN" and TDL_Translate then
            zone = TDL_Translate(zone, "ZONE")
            killer = TDL_Translate(killer, "NPC")
        end
        
        if TDL_PvP_NPC_Dict and (TDL_PvP_NPC_Dict[originalKiller] or TDL_PvP_NPC_Dict[killer]) then 
            isPvP = true 
        end

        if isPvP and not string.find(string.lower(killer), "%-pvp") then killer = killer .. " -pvp" end
        return name, level, killer, zone
    end
    return nil, nil, nil, nil
end

coreFrame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        elapsed = 0
    elseif event == "CHAT_MSG_CHANNEL_JOIN" then
        if arg9 and string.find(string.lower(arg9), string.lower(SYNC_CHANNEL)) and arg2 then
            TDL_ActiveUsers[arg2] = GetTime()
        end
    elseif event == "CHAT_MSG_CHANNEL_LEAVE" then
        if arg9 and string.find(string.lower(arg9), string.lower(SYNC_CHANNEL)) and arg2 then
            TDL_ActiveUsers[arg2] = nil
        end
        
    elseif event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_BROADCAST" or event == "CHAT_MSG_SERVER_EMOTE" or event == "CHAT_MSG_INFO" then
        local name, level, killer, broadcastZone = ParseDeathMessage(arg1)
        if name and level and killer then
            local timeStr = TDL_GetServerTimeStr()
            local zone = broadcastZone or GetZoneText() or (GetLocale() == "zhCN" and "未知区域" or "Unknown Zone")
            local deathData = name.."#"..level.."#"..zone.."#"..killer.."#"..timeStr
            
            local isNewOrUpdated = InsertOrMergeRecord(currentMonth, deathData)
            if isNewOrUpdated then
                table.insert(TDL_SendQueue, PREFIX_DEATH .. currentMonth .. "^" .. deathData)
                if TDL_MainFrame and TDL_MainFrame:IsVisible() and TDL_UpdateList then TDL_UpdateList() end
            end
        end
    elseif event == "CHAT_MSG_CHANNEL" then
        if arg9 and string.find(string.lower(arg9), string.lower(SYNC_CHANNEL)) then
            if arg2 then TDL_ActiveUsers[arg2] = GetTime() end 
            
            if arg2 ~= UnitName("player") then
                if string.find(arg1, "^TDL_REQ_SYNC") then
                    if TDL_SyncDelayTimer <= 0 then
                        TDL_PendingSyncQueue = {}
                        if TDL_HistoryDB[currentMonth] then
                            local records = TDL_HistoryDB[currentMonth]
                            local total = table.getn(records)
                            local maxSync = 15
                            local startIdx = total - maxSync + 1
                            if startIdx < 1 then startIdx = 1 end
                            
                            for i = startIdx, total do
                                local rec = records[i]
                                local tStrPart = string.match(rec, "#([^#]+)$")
                                if tStrPart and string.len(tStrPart) <= 16 then
                                    table.insert(TDL_PendingSyncQueue, PREFIX_DEATH .. currentMonth .. "^" .. rec)
                                end
                            end
                            
                            local activeCount = 1 
                            local now = GetTime()
                            for k, v in pairs(TDL_ActiveUsers) do
                                if now - v < 3600 then
                                    activeCount = activeCount + 1
                                else
                                    TDL_ActiveUsers[k] = nil
                                end
                            end
                            
                            local maxDelay = activeCount * 3
                            if maxDelay < 3 then maxDelay = 3 end
                            
                            TDL_SyncDelayTimer = math.random(10, maxDelay * 10) / 10.0
                        end
                    end
                    
                elseif string.find(arg1, "^TDL_VER:") then
                    local netVer = string.sub(arg1, 9)
                    local nV = GetVerNum(netVer)
                    local lV = GetVerNum(TDL_Dict_Version)
                    
                    if nV > lV and not hasWarnedVer then
                        hasWarnedVer = true
                        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TDL]|r |cffff0000【版本落后警告】|r检测到全网有更高版本的汉化字典库: |cffffff00v" .. netVer .. "|r (您当前为 v" .. (TDL_Dict_Version or "1.0.0") .. ")")
                    end
                    
                elseif string.find(arg1, "^" .. PREFIX_DEATH) then
                    local payload = string.sub(arg1, string.len(PREFIX_DEATH) + 1)
                    
                    local pipePos = string.find(payload, "%^")
                    if pipePos then
                        local syncMonth = string.sub(payload, 1, pipePos - 1)
                        local dataStr = string.sub(payload, pipePos + 1)
                        
                        local parts = {}
                        local currentPos = 1
                        while true do
                            local startPos, endPos = string.find(dataStr, "#", currentPos)
                            if not startPos then table.insert(parts, string.sub(dataStr, currentPos)) break end
                            table.insert(parts, string.sub(dataStr, currentPos, startPos - 1))
                            currentPos = endPos + 1
                        end
                        
                        if table.getn(parts) >= 5 then
                            local name, lvl, zone, killer, timeStr = parts[1], parts[2], parts[3], parts[4], parts[5]
                            
                            if GetLocale() == "zhCN" and TDL_Translate then
                                local origKiller = killer
                                local isPvP = false
                                if string.find(string.lower(killer), " %-pvp$") then
                                    origKiller = string.sub(killer, 1, string.len(killer) - 5)
                                    isPvP = true
                                end
                                
                                zone = TDL_Translate(zone, "ZONE")
                                killer = TDL_Translate(origKiller, "NPC")
                                if isPvP then killer = killer .. " -pvp" end
                                dataStr = name.."#"..lvl.."#"..zone.."#"..killer.."#"..timeStr
                            end
                        end
                        
                        local suppressMsg = PREFIX_DEATH .. syncMonth .. "^" .. dataStr
                        for i = table.getn(TDL_PendingSyncQueue), 1, -1 do
                            if TDL_PendingSyncQueue[i] == suppressMsg then 
                                table.remove(TDL_PendingSyncQueue, i) 
                            end
                        end
                        
                        for i = table.getn(TDL_SendQueue), 1, -1 do
                            if TDL_SendQueue[i] == suppressMsg then 
                                table.remove(TDL_SendQueue, i) 
                            end
                        end
                        
                        TDL_ReceiveData.totalCount = TDL_ReceiveData.totalCount + 1
                        TDL_ReceiveData.active = true
                        TDL_ReceiveData.timer = 0
                        
                        local isNewOrUpdated = InsertOrMergeRecord(syncMonth, dataStr)
                        if isNewOrUpdated then
                            TDL_ReceiveData.newCount = TDL_ReceiveData.newCount + 1
                            if TDL_MainFrame and TDL_MainFrame:IsVisible() and TDL_UpdateList then TDL_UpdateList() end
                        end
                    end
                end
            end
        end
    end
end)

SLASH_TURTLEDEATHLOG1 = "/tdl"
SlashCmdList["TURTLEDEATHLOG"] = function(msg)
    local command = string.lower(msg or "")
    
    if command == "fix" then
        TDL_CleanDatabase(false)
    elseif command == "clear" then
        TDL_HistoryDB = {}
        TDL_HistoryDB[currentMonth] = {}
        if TDL_UpdateList then TDL_UpdateList() end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TDL]|r " .. (GetLocale() == "zhCN" and "所有当月数据已清空。" or "All data cleared."))
    elseif command == "minimap" then
        if TDL_MinimapButton:IsVisible() then TDL_MinimapButton:Hide() else TDL_MinimapButton:Show() end
    else
        if TDL_MainFrame:IsVisible() then TDL_MainFrame:Hide() else TDL_MainFrame:Show(); if TDL_UpdateList then TDL_UpdateList() end end
    end
end
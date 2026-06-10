-- ==========================================================
-- Core.lua - Turtle Death Log (V2.0.1修复章鱼服卡死 + 跨时区与自动清理优化版)
-- ==========================================================
if type(TDL_HistoryDB) ~= "table" then TDL_HistoryDB = {} end

-- 动态获取服务器月份（统一使用本地时间，解决时差丢数据问题）
local function GetCurrentMonth()
    return date("%Y-%m")
end

local cMonth = GetCurrentMonth()
if type(TDL_HistoryDB[cMonth]) ~= "table" then TDL_HistoryDB[cMonth] = {} end

if type(TDL_Database) == "table" and table.getn(TDL_Database) > 0 then
    for _, v in ipairs(TDL_Database) do table.insert(TDL_HistoryDB[cMonth], v) end
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

local function TDL_Msg(cnText, enText)
    local txt = (GetLocale() == "zhCN") and cnText or (enText or cnText)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TDL]|r " .. txt)
end

local function TDL_Err(cnText, enText)
    local txt = (GetLocale() == "zhCN") and cnText or (enText or cnText)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[TDL-Error]|r " .. txt)
end

local function TDL_BgMsg(cnText, enText)
    local txt = (GetLocale() == "zhCN") and cnText or (enText or cnText)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[TDL-Sync]|r " .. txt)
end

local TDL_Reverse_Zone = nil
local TDL_Reverse_NPC = nil

local function InitReverseDicts()
    if TDL_Reverse_Zone then return end
    TDL_Reverse_Zone = {}
    TDL_Reverse_NPC = {}
    local function addRev(dict, target)
        if type(dict) == "table" then
            for en, cn in pairs(dict) do
                if type(cn) == "string" and type(en) == "string" then target[cn] = en end
            end
        end
    end
    addRev(TDL_ZoneDict, TDL_Reverse_Zone)
    addRev(TDL_TempZoneDict, TDL_Reverse_Zone)
    addRev(TDL_NPCDict, TDL_Reverse_NPC)
    addRev(TDL_TempNPCDict, TDL_Reverse_NPC)
    addRev(TDL_PvP_NPC_Dict, TDL_Reverse_NPC)
end

local function TDL_GetEnglish(cnText, dictType)
    if not cnText or cnText == "" then return cnText end
    InitReverseDicts()
    if dictType == "ZONE" then return TDL_Reverse_Zone[cnText] or cnText end
    if dictType == "NPC" then return TDL_Reverse_NPC[cnText] or cnText end
    return cnText
end

-- 获取记录时间（统一使用本地时间，彻底杜绝服务器时间跨日或跨月溢出）
function TDL_GetServerTimeStr()
    return date("%Y-%m-%d %H:%M")
end

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
            if i > 1 and type(list[i-1]) == "number" then return list[i-1] end
        end
    end
    return 0
end

local function GetMinuteTime(tStr) return string.sub(tStr or "", 1, 16) end
local function GetDateOnly(tStr) return string.sub(tStr or "", 1, 10) end

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

local function GetBest24HTime(t1, t2)
    if not t1 or t1 == "" then return t2 end
    if not t2 or t2 == "" then return t1 end
    local _, _, h1 = string.find(t1, " (%d+):")
    local _, _, h2 = string.find(t2, " (%d+):")
    if (tonumber(h1) or -1) > (tonumber(h2) or -1) then return t1 else return t2 end
end

local function MergeBestData(z1, k1, z2, k2)
    local bestZ = z1
    local bestK = k1
    if (not bestZ or bestZ == "Unknown Zone" or bestZ == "未知区域" or bestZ == "") and z2 then bestZ = z2 end
    if (not bestK or bestK == "Environment" or bestK == "未知" or bestK == "") and k2 then bestK = k2 end
    return bestZ, bestK
end

local function InsertOrMergeRecord(month, dataStr)
    if type(TDL_HistoryDB) ~= "table" then TDL_HistoryDB = {} end
    if type(TDL_HistoryDB[month]) ~= "table" then TDL_HistoryDB[month] = {} end
    
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
    else
        return false 
    end
    
    if not name or not timeStr then return false end
    
    local targetDate = GetDateOnly(timeStr)
    local targetFullTime = GetMinuteTime(timeStr)
    local targetDateAbs = GetAbsoluteDay(targetDate)
    
    for m, dataArr in pairs(TDL_HistoryDB) do
        for i, oldDataStr in ipairs(dataArr) do
            local oParts = {}
            local oPos = 1
            while true do
                local sPos, ePos = string.find(oldDataStr, "#", oPos)
                if not sPos then table.insert(oParts, string.sub(oldDataStr, oPos)) break end
                table.insert(oParts, string.sub(oldDataStr, oPos, sPos - 1))
                oPos = ePos + 1
            end
            
            local oName, oLvl, oZone, oKiller, oTimeStr
            if table.getn(oParts) >= 7 then
                oName, oLvl, oZone, oKiller, oTimeStr = oParts[1], oParts[2], oParts[5], oParts[6], oParts[7]
            elseif table.getn(oParts) >= 5 then
                oName, oLvl, oZone, oKiller, oTimeStr = oParts[1], oParts[2], oParts[3], oParts[4], oParts[5]
            end
            
            if oName and oTimeStr then
                local oDateAbs = GetAbsoluteDay(GetDateOnly(oTimeStr))
                -- [核心优化]: 将前后1天合并放宽至前后3天合并
                if targetDateAbs > 0 and oDateAbs > 0 and oName == name and (oLvl or "0") == (lvl or "0") and math.abs(oDateAbs - targetDateAbs) <= 3 then
                    local bestZone, bestKiller = MergeBestData(zone, killer, oZone, oKiller)
                    local bestLvl = lvl or oLvl or "0"
                    local bestTime = GetBest24HTime(targetFullTime, GetMinuteTime(oTimeStr)) or targetFullTime or "2000-01-01 00:00"
                    local mergedData = (oName or "Unknown").."#"..bestLvl.."#"..(bestZone or "Unknown Zone").."#"..(bestKiller or "Unknown").."#"..bestTime
                    if oldDataStr ~= mergedData then
                        TDL_HistoryDB[m][i] = mergedData 
                        return true
                    end
                    return false
                end
            end
        end
    end
    
    local sanitizedData = (name or "Unknown").."#"..(lvl or "0").."#"..(zone or "Unknown Zone").."#"..(killer or "Unknown").."#"..(targetFullTime or "2000-01-01 00:00")
    table.insert(TDL_HistoryDB[month], sanitizedData)
    return true
end

local function TDL_CleanDatabase(isAuto)
    if type(TDL_HistoryDB) ~= "table" then return end
    
    local allRecords = {}
    for month, dataArr in pairs(TDL_HistoryDB) do
        for _, dataStr in ipairs(dataArr) do table.insert(allRecords, {m = month, d = dataStr}) end
    end
    
    local oldTotal = table.getn(allRecords)
    TDL_HistoryDB = {}
    
    for _, item in ipairs(allRecords) do
        local parts = {}
        local cPos = 1
        while true do
            local sPos, ePos = string.find(item.d, "#", cPos)
            if not sPos then table.insert(parts, string.sub(item.d, cPos)) break end
            table.insert(parts, string.sub(item.d, cPos, sPos - 1))
            cPos = ePos + 1
        end
        
        local name, lvl, zone, killer, timeStr
        if table.getn(parts) >= 7 then
            name, lvl, zone, killer, timeStr = parts[1], parts[2], parts[5], parts[6], parts[7]
        elseif table.getn(parts) >= 5 then
            name, lvl, zone, killer, timeStr = parts[1], parts[2], parts[3], parts[4], parts[5]
        end
        
        if name and timeStr then
            local safeKiller = killer or "Unknown"
            local safeZone = zone or "Unknown Zone"
            if GetLocale() == "zhCN" then
                local origK = safeKiller
                local isPvP = false
                if string.find(string.lower(origK), " %-pvp$") then
                    origK = string.sub(origK, 1, string.len(origK) - 5)
                    isPvP = true
                end
                safeZone = TDL_GetEnglish(safeZone, "ZONE") or "Unknown Zone"
                safeKiller = TDL_GetEnglish(origK, "NPC") or "Unknown"
                if isPvP then safeKiller = safeKiller .. " -pvp" end
            end
            local cleanData = name.."#"..(lvl or "0").."#"..safeZone.."#"..safeKiller.."#"..timeStr
            InsertOrMergeRecord(item.m, cleanData)
        end
    end
    
    local newTotal = 0
    for month, dataArr in pairs(TDL_HistoryDB) do newTotal = newTotal + table.getn(dataArr) end
    local dupCount = oldTotal - newTotal
    
    if TDL_UpdateList then TDL_UpdateList() end
    if isAuto then
        if dupCount > 0 then TDL_BgMsg("后台同步与跨日查重完毕！清理了 " .. dupCount .. " 条冗余数据。", "Background sync complete! Cleared " .. dupCount .. " redundant entries.") end
    else
        TDL_Msg("数据库跨日查重与智能反编译完成！清理了 " .. dupCount .. " 条冗余。", "Database cleansed! Removed " .. dupCount .. " duplicates.")
    end
end

local TDL_LastSyncRequestTime = 0
function TDL_RequestSync()
    local now = GetTime()
    if now - TDL_LastSyncRequestTime < 10 then
        TDL_Err("频道正在同步或冷却中，请勿频繁点击！(冷却10秒)", "Channel is syncing or on cooldown! (10s)")
        return
    end
    TDL_LastSyncRequestTime = now
    local id = GetSafeChannelID()
    if id > 0 then
        SendChatMessage("TDL_REQ_SYNC", "CHANNEL", nil, id)
        SendChatMessage("TDL_VER:" .. (TDL_Dict_Version or "1.0.0"), "CHANNEL", nil, id)
    else
        TDL_Err("同步失败：尚未连接到数据网络，请等待后台自动连接。", "Sync failed: Not connected to the data network yet.")
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
-- 【新增】：把大喊和公会频道也加入监听，防止私服魔改底层事件
coreFrame:RegisterEvent("CHAT_MSG_YELL")
coreFrame:RegisterEvent("CHAT_MSG_MONSTER_YELL")
coreFrame:RegisterEvent("CHAT_MSG_GUILD")

local delayFrame = CreateFrame("Frame")
local elapsed = 0
local joinTimer = 0
local TDL_IsJoinedSyncChannel = false
local TDL_InitialCleanDone = false 

TDL_PendingSyncQueue = {} 
TDL_SendQueue = {}        
local TDL_SyncDelayTimer = 0 
local sendTimer = 0

-- [核心优化]: 定时器配置
local TDL_AutoCleanTimer = -1
local TDL_PeriodicCleanTimer = 1800.0 -- 新增: 每30分钟（1800秒）触发一次全局清理

delayFrame:SetScript("OnUpdate", function()
    local dt = arg1 or 0.05
    elapsed = elapsed + dt
    
    if not TDL_InitialCleanDone and elapsed > 60 then
        TDL_InitialCleanDone = true
        TDL_CleanDatabase(true)
    end
    
    if elapsed > 15 then
        joinTimer = joinTimer + dt
        if joinTimer > 8 then
            joinTimer = 0
            local id = GetSafeChannelID()
            if id == 0 then JoinChannelByName(SYNC_CHANNEL, SYNC_PASSWORD, nil) 
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
                for _, msg in ipairs(TDL_PendingSyncQueue) do table.insert(TDL_SendQueue, msg) end
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
            -- [核心优化]: 同步结束后10分钟（600秒）进行一次数据整理
            TDL_AutoCleanTimer = 600.0
        end
    end
    
    if TDL_AutoCleanTimer > 0 then
        TDL_AutoCleanTimer = TDL_AutoCleanTimer - dt
        if TDL_AutoCleanTimer <= 0 then
            TDL_CleanDatabase(true)
            TDL_AutoCleanTimer = -1
        end
    end

    -- [核心优化]: 每30分钟执行一次强制定期清理
    if TDL_PeriodicCleanTimer > 0 then
        TDL_PeriodicCleanTimer = TDL_PeriodicCleanTimer - dt
        if TDL_PeriodicCleanTimer <= 0 then
            TDL_CleanDatabase(true)
            TDL_PeriodicCleanTimer = 1800.0 -- 重新开始下一个30分钟倒计时
        end
    end
end)

-- ==========================================
-- 重点更新区：分段解析，彻底解决引擎死机回溯
-- ==========================================
local function ParseDeathMessage(msg)
    if type(msg) ~= "string" then return nil, nil, nil, nil end
    if not (string.find(msg, "fallen") or string.find(msg, "died") or string.find(msg, "Killed by") or 
            string.find(msg, "击杀") or string.find(msg, "享年") or string.find(msg, "摔死") or 
            string.find(msg, "溺水") or string.find(msg, "淹死") or string.find(msg, "岩浆") or 
            string.find(msg, "烧死") or string.find(msg, "跌死")) then
        return nil, nil, nil, nil
    end
    
    local cleanMsg = string.gsub(msg, "|c%x%x%x%x%x%x%x%x", "")
    cleanMsg = string.gsub(cleanMsg, "|H.-|h(.-)|h", "%1")
    cleanMsg = string.gsub(cleanMsg, "|r", "")
    
    local name, zone, killer, level
    local isPvP = false

    if string.find(cleanMsg, "fallen in PvP") or string.find(cleanMsg, "Mak'gora") or 
       string.find(cleanMsg, "决斗") or string.find(cleanMsg, "被玩家") or 
       string.find(cleanMsg, "级玩家") or string.find(cleanMsg, "%[PVP") then 
       isPvP = true 
    end

    -- 1. 英文格式保护 (格式固定不变，安全匹配)
    if not name then _, _, name, level, killer, zone = string.find(cleanMsg, "character ([^%(]+) %(level (%d+)%) has fallen.-to ([^%(]+) %(level %d+%) in ([^%.]+)%.") end
    if not name then _, _, level, name, zone, killer = string.find(cleanMsg, "Level (%d+) %S+ ([^%s]+) has died in ([^%.]+)%. Killed by ([^%.]+)%.") end
    if not name then _, _, level, name, zone = string.find(cleanMsg, "Level (%d+) %S+ ([^%s]+) has died in ([^%.]+)%.") if name then killer = "Environment" end end

    -- 2. 中文格式优化 (新旧格式与错位格式全兼容，无回溯死机风险)
    if not name and not TDL_ForceEnglish then
        -- 安全提取所有数字以找寻等级
        local lvls = {}
        for num in string.gfind(cleanMsg, "(%d+)") do
            table.insert(lvls, num)
        end
        local parsedLevel = lvls[table.getn(lvls)]
        
        -- A. 环境死亡匹配
        local envKeywords = {"摔死", "溺水", "淹死", "岩浆", "烧死", "跌死"}
        for _, kw in ipairs(envKeywords) do
            if string.find(cleanMsg, kw) then
                _, _, name = string.find(cleanMsg, "玩家%s*([^%s在]+)")
                if not name then _, _, name = string.find(cleanMsg, "([^%s]+)%s*在") end
                
                -- 【修复】：支持带空格的英文地名，直到遇到死因关键字才停止
                _, _, zone = string.find(cleanMsg, "在%s*(.-)%s*" .. kw)
                if not zone then _, _, zone = string.find(cleanMsg, "在%s*([^" .. kw .. "]+)") end
                
                if name then
                    killer = kw
                    level = parsedLevel or "0"
                    break
                end
            end
        end

        -- B. 击杀死亡匹配 (采用无贪婪多步拆分，彻底避免死锁)
        if not name and string.find(cleanMsg, "击杀") then
            -- 提取玩家名字
            _, _, name = string.find(cleanMsg, "玩家%s*([^%s在被]+)")
            if not name then _, _, name = string.find(cleanMsg, "享年%d+级%s*([^%s]+)") end
            if not name then _, _, name = string.find(cleanMsg, "级%S*%s+([^%s在被]+)%s*在") end
            
            -- 【修复】：提取区域地点（支持空格，遇到“被”字才停止匹配）
            _, _, zone = string.find(cleanMsg, "在%s*(.-)%s*被")
            if not zone then _, _, zone = string.find(cleanMsg, "在%s*([^被]+)") end
            
            -- 提取杀手信息并剥离冗余等级修饰
            local rawKiller
            _, _, rawKiller = string.find(cleanMsg, "被([^击杀]+)击杀")
            if rawKiller then
                _, _, killer = string.find(rawKiller, "级玩家%s*(.+)")
                if not killer then _, _, killer = string.find(rawKiller, "级%s*(.+)") end
                if not killer then killer = rawKiller end
            end

            -- 信息有效性验证
            if name and killer then
                level = parsedLevel or "0"
                if not zone then zone = "Unknown Zone" end
            else
                name = nil -- 验证失败抛弃
            end
        end
    end

    -- 3. 数据清洗与兜底处理
    if name and killer and zone and level then
        -- 非法记录抛弃处理 (防止名字带空格或等级缺失的脏数据存入)
        if string.find(name, " ") or not tonumber(level) then return nil, nil, nil, nil end
        
        name = string.gsub(name, "^%s*(.-)%s*$", "%1")
        zone = string.gsub(zone, "^%s*(.-)%s*$", "%1")
        killer = string.gsub(killer, "^%s*(.-)%s*$", "%1")
        killer = string.gsub(killer, "[。！!，,]$", "")
        
        if GetLocale() == "zhCN" then
            zone = TDL_GetEnglish(zone, "ZONE") or zone
            killer = TDL_GetEnglish(killer, "NPC") or killer
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
        if arg9 and string.find(string.lower(arg9), string.lower(SYNC_CHANNEL)) and arg2 then TDL_ActiveUsers[arg2] = GetTime() end
    elseif event == "CHAT_MSG_CHANNEL_LEAVE" then
        if arg9 and string.find(string.lower(arg9), string.lower(SYNC_CHANNEL)) and arg2 then TDL_ActiveUsers[arg2] = nil end
    elseif event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_BROADCAST" or event == "CHAT_MSG_SERVER_EMOTE" or event == "CHAT_MSG_INFO" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_MONSTER_YELL" or event == "CHAT_MSG_GUILD" then
        local name, level, killer, broadcastZone = ParseDeathMessage(arg1)
        if name and level and killer then
            local timeStr = TDL_GetServerTimeStr()
            local rawFallbackZone = broadcastZone or GetZoneText() or "Unknown Zone"
            if GetLocale() == "zhCN" and rawFallbackZone ~= "Unknown Zone" then rawFallbackZone = TDL_GetEnglish(rawFallbackZone, "ZONE") or rawFallbackZone end
            
            local cM = GetCurrentMonth()
            local deathData = name.."#"..level.."#"..rawFallbackZone.."#"..killer.."#"..timeStr
            if InsertOrMergeRecord(cM, deathData) then
                table.insert(TDL_SendQueue, PREFIX_DEATH .. cM .. "^" .. deathData)
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
                        
                        local nowStr = string.sub(TDL_GetServerTimeStr and TDL_GetServerTimeStr() or date("%Y-%m-%d"), 1, 10)
                        local currentAbs = GetAbsoluteDay(nowStr)
                        
                        local recentRecords = {}
                        if type(TDL_HistoryDB) == "table" then
                            for m, records in pairs(TDL_HistoryDB) do
                                for _, rec in ipairs(records) do
                                    local parts = {}
                                    local cPos = 1
                                    while true do
                                        local sPos, ePos = string.find(rec, "#", cPos)
                                        if not sPos then table.insert(parts, string.sub(rec, cPos)) break end
                                        table.insert(parts, string.sub(rec, cPos, sPos - 1))
                                        cPos = ePos + 1
                                    end
                                    local timeStr = parts[table.getn(parts)]
                                    
                                    if timeStr and string.len(timeStr) <= 16 then
                                        local recDate = string.sub(timeStr, 1, 10)
                                        local recAbs = GetAbsoluteDay(recDate)
                                        if recAbs > 0 and (currentAbs - recAbs) <= 20 and (currentAbs - recAbs) >= 0 then
                                            table.insert(recentRecords, {month = m, data = rec, t = timeStr})
                                        end
                                    end
                                end
                            end
                        end
                        
                        table.sort(recentRecords, function(a, b) return a.t > b.t end)
                        
                        local maxSync = 25
                        local syncCount = table.getn(recentRecords)
                        if syncCount > maxSync then syncCount = maxSync end
                        
                        for i = syncCount, 1, -1 do
                            local item = recentRecords[i]
                            table.insert(TDL_PendingSyncQueue, PREFIX_DEATH .. item.month .. "^" .. item.data)
                        end
                        
                        local activeCount = 1 
                        local now = GetTime()
                        for k, v in pairs(TDL_ActiveUsers) do
                            if now - v < 3600 then activeCount = activeCount + 1 else TDL_ActiveUsers[k] = nil end
                        end
                        local maxDelay = activeCount * 3
                        if maxDelay < 3 then maxDelay = 3 end
                        TDL_SyncDelayTimer = math.random(10, maxDelay * 10) / 10.0
                    end
                elseif string.find(arg1, "^TDL_VER:") then
                    local netVer = string.sub(arg1, 9)
                    if GetVerNum(netVer) > GetVerNum(TDL_Dict_Version) and not hasWarnedVer then
                        hasWarnedVer = true
                        TDL_Msg("|cffff0000【版本落后警告】|r检测到全网有更高版本的汉化字典库: |cffffff00v" .. netVer .. "|r", "|cffff0000[Outdated Warning]|r Higher dictionary version detected on network: |cffffff00v" .. netVer .. "|r")
                    end
                elseif string.find(arg1, "^" .. PREFIX_DEATH) then
                    local payload = string.sub(arg1, string.len(PREFIX_DEATH) + 1)
                    local pipePos = string.find(payload, "%^")
                    if pipePos then
                        local syncMonth = string.sub(payload, 1, pipePos - 1)
                        local dataStr = string.sub(payload, pipePos + 1)
                        local suppressMsg = PREFIX_DEATH .. syncMonth .. "^" .. dataStr
                        for i = table.getn(TDL_PendingSyncQueue), 1, -1 do if TDL_PendingSyncQueue[i] == suppressMsg then table.remove(TDL_PendingSyncQueue, i) end end
                        for i = table.getn(TDL_SendQueue), 1, -1 do if TDL_SendQueue[i] == suppressMsg then table.remove(TDL_SendQueue, i) end end
                        
                        TDL_ReceiveData.totalCount = TDL_ReceiveData.totalCount + 1
                        TDL_ReceiveData.active = true
                        TDL_ReceiveData.timer = 0
                        
                        if InsertOrMergeRecord(syncMonth, dataStr) then
                            TDL_ReceiveData.newCount = TDL_ReceiveData.newCount + 1
                            if TDL_MainFrame and TDL_MainFrame:IsVisible() and TDL_UpdateList then TDL_UpdateList() end
                        end
                    end
                end
            end
        else
            -- 【新增】：捕获 [HC] 等其他聊天频道的死亡通告
            local name, level, killer, broadcastZone = ParseDeathMessage(arg1)
            if name and level and killer then
                local timeStr = TDL_GetServerTimeStr()
                local rawFallbackZone = broadcastZone or GetZoneText() or "Unknown Zone"
                if GetLocale() == "zhCN" and rawFallbackZone ~= "Unknown Zone" then rawFallbackZone = TDL_GetEnglish(rawFallbackZone, "ZONE") or rawFallbackZone end
                
                local cM = GetCurrentMonth()
                local deathData = name.."#"..level.."#"..rawFallbackZone.."#"..killer.."#"..timeStr
                if InsertOrMergeRecord(cM, deathData) then
                    table.insert(TDL_SendQueue, PREFIX_DEATH .. cM .. "^" .. deathData)
                    if TDL_MainFrame and TDL_MainFrame:IsVisible() and TDL_UpdateList then TDL_UpdateList() end
                end
            end
        end
    end
end)

SLASH_TURTLEDEATHLOG1 = "/tdl"
SlashCmdList["TURTLEDEATHLOG"] = function(msg)
    local command = string.lower(msg or "")
    if command == "fix" then TDL_CleanDatabase(false)
    elseif command == "clear" then
        TDL_HistoryDB = {}
        local cM = GetCurrentMonth()
        TDL_HistoryDB[cM] = {}
        if TDL_UpdateList then TDL_UpdateList() end
        TDL_Msg("所有本地数据已清空。", "All local data cleared.")
    elseif command == "minimap" then
        if TDL_MinimapButton:IsVisible() then TDL_MinimapButton:Hide() else TDL_MinimapButton:Show() end
    else
        if TDL_MainFrame:IsVisible() then TDL_MainFrame:Hide() else TDL_MainFrame:Show(); if TDL_UpdateList then TDL_UpdateList() end end
    end
end

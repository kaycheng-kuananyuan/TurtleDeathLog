Turtle Death Log (TDL) - Hardcore Death Tracker & P2P Sync Grid for Turtle WoW
Turtle Death Log (TDL) - 乌龟服硬核死亡记录与全网同步网格
Turtle Death Log (TDL) is a lightweight, decentralized death tracker and synchronization add-on specifically designed for the World of Warcraft 1.12 Vanilla Hardcore mode.
Turtle Death Log (TDL) 是一款专为《魔兽世界》1.12 香草时代硬核（Hardcore）模式打造的轻量级、去中心化死亡追踪与全网同步插件。

More than just a local death logger, TDL builds an invisible P2P data synchronization network based on the CSMA/CD (Carrier-Sense Multiple Access with Collision Detection) concept, overcoming the extremely restricted underlying APIs of the 1.12 client. By simply enabling the add-on, players can silently share and receive hardcore death data across the entire network in the background, collectively weaving an epic epitaph for hardcore players.
TDL 不仅仅是一个本地的死亡记录器，它还在 1.12 极其受限的底层 API 中，构建了一个基于 CSMA/CD（载波侦听多路访问/冲突检测）理念的隐形 P2P 数据同步网络。玩家只需开启插件，即可在后台静默共享和接收全网的硬核死亡数据，共同编织一部硬核玩家的史诗墓志铭。

✨ Core Features
✨ 核心特性
🌐 Invisible P2P Synchronization Grid

🌐 隐形 P2P 全网同步网格

Utilizes a hidden underlying channel (tdl_sync_channel_v1) for silent data handshakes.

利用底层隐藏频道（tdl_sync_channel_v1）进行静默数据握手。

Dynamic Node Radar & Backoff Algorithm: Intelligently detects the number of active nodes in the current network and dynamically scales the synchronization roll delay (dice mechanism). Through silent background listening, it completely eliminates "broadcast storms" and channel crashes caused by multiple players sending data simultaneously.

动态节点雷达与退避算法： 智能侦测当前网络活跃人数，动态放大同步掷点延迟（骰子机制）。通过后台静默监听，彻底杜绝多玩家同时发送数据引发的“广播风暴”和频道崩溃。

🚀 SuperWoW Dual-Core Drive & Disconnect Protection

🚀 SuperWoW 双核驱动与防掉线保护

内置智能探针。当检测到标准客户端时，它会在3.5秒/消息时启用极端防断安全引擎；当检测到SuperWoW模块时，它会自动切换到3.0秒/消息的加速同步引擎。

内置智能探针。检测到普通客户端时，启用 3.5秒/条 的极限防掉线安全引擎；检测到安装了 SuperWoW 模组时，自动切换至 3.0秒/条 的提速同步引擎。

 GMT 全球统一时间线 & 智能去重

🕸️ 全球统一时间轴与智能去重

跨时区支持：一种原创的时间差桥梁算法强制将所有本地数据转换为全球统一的24小时服务器时间（精确到分钟），解决了由于全球玩家之间的时间差导致的克隆数据问题。

跨越时区：独创时差桥接算法，强制将所有本地数据转化为全球统一的24小时制服务器时间（精确到分钟），解决中外玩家因时差导致的克隆数据。

Hardcore Data Cleansing Engine: As long as the "Name + Level + YYYY-MM-DD" match exactly, it is judged as the same death. It automatically "eliminates the inferior and retains the superior" (keeps the most complete translated fields) from multiple records, thoroughly eliminating duplicates caused by network latency.

硬核级洗数据引擎： 只要“名字 + 等级 + 年月日”一致，即判定为同一次死亡，并自动从多条记录中“汰劣留良”（保留翻译最完整的字段），彻底消灭因网络延迟产生的重复冗余。

📂 Monthly Independent File Storage

📂 按月分卷独立存储

To completely solve the lag caused by the infinite expansion of log files, and to facilitate hardcore communities in publishing "casualty lists" by month on forums, TDL's data structure has been specially designed. All death records are saved monthly into independent file nodes (e.g., TDL_HistoryDB["2026-05"]).

为了彻底解决日志文件无限膨胀导致的卡顿，并方便硬核社区在论坛上按月发布“阵亡名单”，TDL 的数据结构经过特别设计，所有死亡记录均按月保存至独立的文件节点中（如 TDL_HistoryDB["2026-05"]）。

🔤 Highly Extensible Localization Dictionary

🔤 高度可拓展的汉化字典

Built-in standardized English-Chinese core dictionary, with dedicated areas for TDL_TempZoneDict (temporary zones) and TDL_TempNPCDict (temporary mobs). When encountering a new mob, it can be perfectly translated with just one simple line of code.

内置标准化的中英对照核心字典，并提供 TDL_TempZoneDict（临时地名）和 TDL_TempNPCDict（临时怪物）专区。遇到新怪物，只需简单一行代码即可完美汉化。

📦 Installation
📦 安装说明
Download the TurtleDeathLog folder.

下载 TurtleDeathLog 文件夹。

Extract it and place it into your World of Warcraft AddOns directory: World of Warcraft\Interface\AddOns\.

将其解压并放入你的魔兽世界插件目录：World of Warcraft\Interface\AddOns\。

Ensure the folder is named TurtleDeathLog.

确保文件夹名称为 TurtleDeathLog。

Enter the game and verify it is checked in the "AddOns" list on the character selection screen.

进入游戏，在人物选择界面的“插件”列表中确认已勾选。

⌨️ Slash Commands
⌨️ 常用命令
You can type the following commands in the chat box to control the add-on:
可以在聊天框输入以下命令来控制插件：

/tdl —— Show/hide the TDL main interface panel.

/tdl —— 呼出/隐藏 TDL 主界面面板。

/tdl fix —— Manually trigger a smart database cleanse (forcibly merge duplicate data of the same day and re-translate historical records with the latest dictionary). Note: The add-on not only supports manual cleansing but will also perform fully automatic silent cleansing in the background 60 seconds after startup and 120 seconds after every sync completes.

/tdl fix —— 手动触发一次数据库智能清洗（强制合并同日重复数据，并以最新字典重新翻译历史旧账）。注：插件不仅支持手动清洗，还会在开机 60 秒后、以及每次同步完成 120 秒后进行后台全自动静默清洗。

/tdl clear —— Clear all local historical data for the current month.

/tdl clear —— 清空当前月份的所有本地历史数据。

/tdl minimap —— Show/hide the minimap button.

/tdl minimap —— 显示/隐藏小地图按钮。

📖 Usage Guide
📖 使用指南
Unlock Network Query: Knowledge requires selfless sharing. Upon first use, you need to click the [Turn on Plugin] button in the lower right corner of the interface. This means you agree to join TDL's background data sharing protocol. Once enabled, query and sync features will be fully unlocked.

解锁全网查询： 知识需要无私的共享。初次使用时，你需要点击界面右下角的 【开启插件】 按钮。这代表你同意加入 TDL 的后台数据共享协议。开启后，查询与同步功能将全面解锁。

Fetch Latest Data: Click [Sync], and your add-on will broadcast a request to the entire network. Nodes with data in the network will silently push missing death records to you after a smart dice roll (10-second cooldown).

获取最新数据： 点击 【刷新同步】，你的插件会向全网广播请求。网络中拥有数据的节点会经过智能掷点后，静默为你推送缺失的死亡记录（冷却时间 10 秒）。

Query Older History: By default, the interface only displays data for the current month. Click [Load Older] to mount independent historical records from previous months across files.

查询更久历史： 默认界面仅展示当前月份的数据。点击 【查询更久】，可跨文件挂载往月的独立历史记录。

Report Custom Death: For extremely special non-combat casualties such as falling off a cliff, drowning, or lava, you can use this feature to mark your cause of death as "Custom Cause" and broadcast it to the network.

报告另类死亡： 针对坠崖、溺水、岩浆等极其特殊的非战斗减员，你可以使用此功能将你的死因标记为“自定义死因”并广播给全网。

🛠️ Advanced: How to Add Translations for New Mobs/Zones?
🛠️ 高级拓展：如何添加新怪物/地点翻译？
If you encounter untranslated English zone names or mob names in the game, you can always open the Data_Dict.lua file in the add-on directory. Scroll to the very bottom of the file and add the data within the corresponding temporary braces. For example:
如果在游戏中遇到未被翻译的英文地名或怪物名，你可以随时打开插件目录下的 Data_Dict.lua 文件。滚动到文件最底部，在相应的临时大括号内添加数据即可。例如：

Lua


-- ==========================================================
-- 临时怪物区 / Temporary Mobs Dictionary
-- ==========================================================
TDL_TempNPCDict = {
    ["Kroshius"] = "克罗休斯",
    ["Strider Clutchmother"] = "陆行鸟巢母",
    ["New English Mob"] = "你自定义的中文名",
}
After saving the file, type /reload in the game to reload the interface, and your old records will be automatically cleansed into the latest Chinese!
保存文件后，在游戏中输入 /reload 重载界面，你的旧记录也会被自动洗成最新的中文！

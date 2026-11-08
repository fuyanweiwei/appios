import Foundation
import SwiftUI

// ====== 顶层类型、数据模型与功能模块目录（与安卓 Models.kt 对齐）======

enum Route: Equatable {
    case login
    case main
}

/// 底部主导航（QQ 式下栏）
enum MainTab: String, CaseIterable, Identifiable {
    case home = "首页"
    case board = "贴板"
    case media = "媒记"
    case features = "功能"
    case tools = "实用"
    var id: String { rawValue }
    var label: String { rawValue }
}

/// 媒记分区（对应网站 media 页的四个子栏）
enum MediaSection: String, CaseIterable, Identifiable {
    case memes = "梗图"
    case photos = "壁纸"
    case draws = "绘画"
    case novels = "小说"
    var id: String { rawValue }
    var label: String { rawValue }
    var apiPath: String {
        switch self {
        case .memes: return "api/memes/seeMemes"
        case .photos: return "api/photos/seePhotos"
        case .draws: return "api/draws/seeDraws"
        case .novels: return "api/novels"
        }
    }
}

/// 全屏覆盖层（栈式）——与安卓 Overlay sealed class 一一对应
enum Overlay: Equatable {
    case featureList(appType: String, title: String)
    case settings
    case profile
    case notifications
    case feedback
    case gift
    case backpack
    case achievement
    case novelDetail(novelId: Int, title: String)
    case novelReader(novelId: Int, chapterId: Int, title: String)
    case composeDaily
    case mediaViewer(items: [MediaItem], index: Int)
    case tasks
    case board
    case boardEdit(noteId: Int?, title: String, content: String, scope: String)
    case composeColumn(id: Int?, title: String, content: String, type: String)
    case featureDetail(appType: String, row: Json)
    case featureEdit(appType: String, title: String, row: Json?)
    case leaderboard
    case gameCenter
    case usageStats
    case toolDetail(id: String, title: String)
    case gameContainer(url: String, title: String)
    case columnDetail(col: Json)
    case giftEdit(gift: Json?)

    static func == (lhs: Overlay, rhs: Overlay) -> Bool {
        switch (lhs, rhs) {
        case let (.featureList(a, b), .featureList(c, d)): return a == c && b == d
        case (.settings, .settings), (.profile, .profile), (.notifications, .notifications),
             (.feedback, .feedback), (.gift, .gift), (.backpack, .backpack),
             (.achievement, .achievement), (.composeDaily, .composeDaily),
             (.tasks, .tasks), (.board, .board), (.leaderboard, .leaderboard),
             (.gameCenter, .gameCenter), (.usageStats, .usageStats): return true
        case let (.novelDetail(a, b), .novelDetail(c, d)): return a == c && b == d
        case let (.novelReader(a, b, c), .novelReader(d, e, f)): return a == d && b == e && c == f
        case let (.mediaViewer(a, b), .mediaViewer(c, d)): return a == c && b == d
        case let (.boardEdit(a, b, c, d), .boardEdit(e, f, g, h)): return a == e && b == f && c == g && d == h
        case let (.composeColumn(a, b, c, d), .composeColumn(e, f, g, h)): return a == e && b == f && c == g && d == h
        case let (.featureDetail(a, b), .featureDetail(c, d)): return a == c && jsonEqual(b, d)
        case let (.featureEdit(a, b, c), .featureEdit(d, e, f)): return a == d && b == e && jsonEqualOpt(c, f)
        case let (.toolDetail(a, b), .toolDetail(c, d)): return a == c && b == d
        case let (.gameContainer(a, b), .gameContainer(c, d)): return a == c && b == d
        case let (.columnDetail(a), .columnDetail(b)): return jsonEqual(a, b)
        case let (.giftEdit(a), .giftEdit(b)): return jsonEqualOpt(a, b)
        default: return false
        }
    }
}

/// Json（[String: Any]）不是 Equatable：走 NSDictionary 值比较
private func jsonEqual(_ a: Json, _ b: Json) -> Bool {
    (a as NSDictionary).isEqual(to: b)
}

private func jsonEqualOpt(_ a: Json?, _ b: Json?) -> Bool {
    switch (a, b) {
    case (nil, nil): return true
    case let (x?, y?): return jsonEqual(x, y)
    default: return false
    }
}

/// 首页分栏
enum HomeFeed: String, CaseIterable, Identifiable {
    case daily = "日常"
    case column = "专栏"
    case dynamic = "动态"
    var id: String { rawValue }
    var label: String { rawValue }
}

struct MediaItem: Identifiable, Equatable {
    let id: Int
    let name: String
    let url: String
    let by: String
    let tags: String
    let score: Int
    /// 分级：0 全年龄 / 1 12+ / 2 18+ / 3 21+（服务端已过滤，仅用于角标）
    let level: Int
    init(id: Int, name: String, url: String, by: String, tags: String, score: Int, level: Int = 0) {
        self.id = id
        self.name = name
        self.url = url
        self.by = by
        self.tags = tags
        self.score = score
        self.level = level
    }
}

struct NovelBrief: Identifiable, Equatable {
    let id: Int
    let title: String
    let cover: String
    let author: String
    let intro: String
    let words: Int
    let reads: Int
}

struct NovelChapterRef: Identifiable, Equatable {
    let id: Int
    let title: String
    let position: Int
}

struct NovelDetailData: Equatable {
    let novel: NovelBrief
    let chapters: [NovelChapterRef]
}

struct FeatureField: Identifiable, Equatable {
    let key: String
    let label: String
    let options: [String]
    var id: String { key }
    init(_ key: String, _ label: String, _ options: [String] = []) {
        self.key = key
        self.label = label
        self.options = options
    }
}

struct FeatureDef: Identifiable, Equatable {
    let appType: String
    let title: String
    let emoji: String
    let fields: [FeatureField]
    var id: String { appType }
    init(_ appType: String, _ title: String, _ emoji: String, _ fields: [FeatureField]) {
        self.appType = appType
        self.title = title
        self.emoji = emoji
        self.fields = fields
    }
}

/// 功能模块目录（P2：字段与网站 FEAT_DEFS 对齐）
let FEATURE_CATALOG: [FeatureDef] = [
    FeatureDef("comic_watch", "番剧追番", "📺", [
        FeatureField("name", "番剧名"), FeatureField("year", "年份"),
        FeatureField("season", "季度", ["冬季", "春季", "夏季", "秋季"]),
        FeatureField("type", "类型"), FeatureField("series", "系列"), FeatureField("episodes", "集数"),
        FeatureField("isEnd", "完结", ["是", "否"]), FeatureField("score", "评分"), FeatureField("detail", "评价"),
    ]),
    FeatureDef("anwei_game", "暗区游戏", "🎯", [
        FeatureField("playerName", "玩家"), FeatureField("gameType", "游戏", ["暗围", "摸金"]),
        FeatureField("mapName", "地图"),
        FeatureField("level", "难度", ["普通", "封锁", "强化封锁", "机密", "绝密"]),
        FeatureField("reaps", "收益"), FeatureField("kill", "击杀"),
        FeatureField("isDied", "撤离", ["否", "是"]), FeatureField("logs", "备注"),
    ]),
    FeatureDef("yisa_game", "以撒游戏", "🎲", [
        FeatureField("character", "角色"),
        FeatureField("mode", "模式", ["普通", "困难", "贪婪", "贪婪+", "挑战", "每日", "虚空"]),
        FeatureField("session", "第几局"), FeatureField("seed", "种子"),
        FeatureField("isWin", "通关", ["否", "是"]), FeatureField("score", "受击"),
        FeatureField("winTimes", "通关次数"), FeatureField("winLogs", "备注"),
    ]),
    FeatureDef("elden_ring", "黑夜君临", "🌙", [
        FeatureField("character", "角色", ["追踪者", "铁之眼", "隐士", "无赖"]),
        FeatureField("mode", "模式", ["普通", "永夜之王", "深夜1", "深夜2"]),
        FeatureField("session", "第几局"), FeatureField("isWin", "通关", ["否", "是"]),
        FeatureField("deathReason", "死亡原因"), FeatureField("runesEarned", "卢恩"), FeatureField("notes", "备注"),
    ]),
    FeatureDef("miao_game", "喵合圣殿", "🐱", [
        FeatureField("name", "名字"), FeatureField("profession", "职业", ["战士", "坦克", "猎人", "法师"]),
        FeatureField("level", "等级"), FeatureField("beauty", "外观"), FeatureField("end", "终点"),
        FeatureField("summary", "简介"),
    ]),
    FeatureDef("mc_mod", "MC模组", "⛏", [
        FeatureField("name", "名称"),
        FeatureField("type", "类型", ["科技", "魔法", "装备", "农业", "美化", "建筑", "实用", "娱乐", "其他"]),
        FeatureField("version", "版本"), FeatureField("loader", "加载器", ["Forge", "Fabric"]),
        FeatureField("scores", "评分"), FeatureField("isInDanger", "有风险", ["否", "是"]),
        FeatureField("details", "描述"),
    ]),
    FeatureDef("singer_famous", "歌者金曲", "🎤", [
        FeatureField("name", "歌手"),
        FeatureField("language", "语言", ["华语", "粤语", "日语", "韩语", "英语", "其他"]),
        FeatureField("gender", "类型", ["男", "女", "组合"]), FeatureField("type", "流派"),
        FeatureField("fame", "知名度"), FeatureField("detail", "概要"),
    ]),
    FeatureDef("food_record", "美食记录", "🍜", [
        FeatureField("name", "店名"), FeatureField("type", "类型"),
        FeatureField("foods", "食物"), FeatureField("scores", "评分"),
        FeatureField("prices", "价格"), FeatureField("details", "评价"),
    ]),
    FeatureDef("online_mood", "联机心情", "🎮", [
        FeatureField("name", "游戏"),
        FeatureField("type", "类型", ["局域网", "网游", "同屏", "服务器"]),
        FeatureField("mood", "心情"), FeatureField("playTime", "时长"),
    ]),
    FeatureDef("hobby_journey", "爱好之旅", "🧭", [
        FeatureField("type", "类型"), FeatureField("level", "优先级"),
        FeatureField("frequency", "频率", ["自由", "每天", "每周", "每月"]),
        FeatureField("process", "进度"),
    ]),
    FeatureDef("daily_song", "每日一首", "🎵", [
        FeatureField("name", "歌名"), FeatureField("singer", "歌手"),
        FeatureField("type", "类型"), FeatureField("score", "评分"),
        FeatureField("detail", "乐评"),
    ]),
    FeatureDef("standalone_appreciation", "单机品鉴", "🕹", [
        FeatureField("name", "游戏"), FeatureField("type", "类型"),
        FeatureField("score", "综合"), FeatureField("scorePicture", "画面"),
        FeatureField("scorePlot", "剧情"), FeatureField("scoreFunny", "趣味"),
        FeatureField("detailUser", "点评"),
    ]),
    FeatureDef("lucky_draw", "今日上签", "🎫", [
        FeatureField("name", "签文"), FeatureField("mode", "模式", ["even", "weighted"]),
        FeatureField("times", "次数"), FeatureField("content", "内容"),
    ]),
    FeatureDef("character_memory", "角色记忆", "👤", [
        FeatureField("characterName", "角色"), FeatureField("animeName", "动漫"),
        FeatureField("animeType", "类型"), FeatureField("gender", "性别"),
        FeatureField("voiceActor", "声优"), FeatureField("overallScore", "综合"),
    ]),
    FeatureDef("anime_music_echo", "漫音回响", "🌸", [
        FeatureField("songName", "歌名"), FeatureField("singer", "歌手"),
        FeatureField("animeName", "动漫"), FeatureField("animeSeason", "季度"),
        FeatureField("musicScore", "评分"), FeatureField("reason", "推荐理由"),
    ]),
    FeatureDef("deep_rock_galaxy", "深岩银河", "🚀", [
        FeatureField("missionName", "任务名"),
        FeatureField("missionType", "类型", ["采矿探险", "虫蛋收集", "就地精炼", "搜救行动", "定点提取", "消灭任务", "执勤护送", "设施破坏", "重型探采"]),
        FeatureField("mapName", "地图", ["水晶洞穴", "盐坑", "霉菌沼泽", "放射性禁区", "密林丛原", "冰封岩层", "熔岩之心", "飞沙走廊", "蔚蓝花甸", "藤络树洞", "栖骨深渊"]),
        FeatureField("difficulty", "难度", ["1", "2", "3", "4", "5"]),
        FeatureField("character", "职业", ["侦察兵", "钻机手", "枪手", "工程师"]),
        FeatureField("isWin", "通关", ["是", "否"]), FeatureField("kills", "击杀"),
    ]),
    FeatureDef("my_best", "我的最佳", "🏆", [
        FeatureField("listName", "榜单"),
        FeatureField("type", "类型", ["游戏", "电影", "音乐", "动漫", "书籍", "美食", "其他"]),
        FeatureField("importance", "重要度"),
    ]),
]

/// 首页日常条目
struct DailyItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let content: String
    let tags: String
    let createdAt: String
    let authorName: String
    /// 配图（服务器相对路径，由 resolveImg 补全）
    let images: [String]
    init(id: Int, title: String, content: String, tags: String, createdAt: String,
         authorName: String, images: [String] = []) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.createdAt = createdAt
        self.authorName = authorName
        self.images = images
    }
}

/// 动态（网站首页最近更新）
struct ActivityItem: Identifiable, Equatable {
    let id: Int
    let userName: String
    let appType: String
    let action: String
    let summary: String
    let createdAt: String
}

/// 今日任务
struct TaskToday: Equatable {
    let recordCount: Int
    let recordCoins: Int
    let checkInCoins: Int
    let totalCoins: Int
    let moodDone: Bool
    let coins: Int
}

/// 贴板私记闹钟（服务端到点发站内通知 + 邮件）
struct BoardAlarmPayload: Equatable {
    let enabled: Bool
    /// ISO 本地时间 yyyy-MM-ddTHH:mm（后端 LocalDateTime.parse 认这个格式）
    let atIso: String
    /// once / daily / weekly / monthly
    let period: String
}

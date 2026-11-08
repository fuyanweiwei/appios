import Foundation

/// 成就定义（与网站 app-core.js ACHIEVEMENTS 对齐）
struct AchDef: Identifiable, Equatable {
    let id: String
    let icon: String
    let name: String
    let desc: String

    init(_ id: String, _ icon: String, _ name: String, _ desc: String) {
        self.id = id
        self.icon = icon
        self.name = name
        self.desc = desc
    }
}

let ACH_DEFS: [AchDef] = [
    AchDef("first_checkin", "📅", "初来乍到", "完成首次签到"),
    AchDef("streak3", "🔥", "三日之约", "连续签到 3 天"),
    AchDef("streak7", "🌋", "七日之约", "连续签到 7 天"),
    AchDef("streak10", "👑", "满勤王者", "连续签到 10 天"),
    AchDef("checkin7", "🗓️", "七日小成", "累计签到 7 天"),
    AchDef("checkin30", "🌟", "月度达人", "累计签到 30 天"),
    AchDef("checkin100", "💯", "百炼成钢", "累计签到 100 天"),
    AchDef("checkin365", "🌈", "一整年陪伴", "累计签到 365 天"),
    AchDef("makeup1", "🔁", "补签初体验", "完成首次补签"),
    AchDef("makeup10", "🩹", "亡羊补牢", "累计补签 10 次"),
    AchDef("coins100", "🪙", "小金库", "拥有 100 金币"),
    AchDef("coins500", "👛", "存款大户", "拥有 500 金币"),
    AchDef("coins1000", "💰", "金库大亨", "拥有 1000 金币"),
    AchDef("coins5000", "🧧", "财神附体", "拥有 5000 金币"),
    AchDef("coins10000", "🦄", "亿点点钱", "拥有 10000 金币"),
    AchDef("post1", "✍️", "初次发帖", "发布第一个帖子"),
    AchDef("post10", "📢", "分享达人", "发布 10 个帖子"),
    AchDef("post20", "🌊", "活跃水怪", "发布 20 个帖子"),
    AchDef("post50", "🎤", "社区红人", "发布 50 个帖子"),
    AchDef("post100", "💬", "话痨之王", "发布 100 个帖子"),
    AchDef("board1", "📌", "贴板新手", "创建第一条贴板私记"),
    AchDef("board10", "📋", "贴板管家", "创建 10 条贴板私记"),
    AchDef("comment1", "💭", "初次评论", "发表第一条评论"),
    AchDef("comment20", "🗣️", "评论积极分子", "累计评论 20 条"),
    AchDef("like1", "👍", "点赞之交", "送出第一个点赞"),
    AchDef("like50", "❤️", "点赞狂魔", "累计送出 50 个赞"),
    AchDef("use3", "🧭", "初窥门径", "使用过 3 个功能"),
    AchDef("use5", "🎯", "涉猎广泛", "使用过 5 个功能"),
    AchDef("use10", "🦾", "工具人本人", "使用过 10 个功能"),
    AchDef("useAll", "⭐", "全知全能", "开启全部功能"),
    AchDef("media1", "🎨", "初出茅庐", "上传 1 个媒页作品"),
    AchDef("media10", "🖼️", "创作大师", "上传 10 个媒页作品"),
    AchDef("media50", "🏆", "创作之神", "上传 50 个媒页作品"),
    AchDef("photo1", "📷", "快门时刻", "上传第一张照片"),
    AchDef("photo10", "📸", "摄影爱好者", "上传 10 张照片"),
    AchDef("novel1", "📖", "提笔写作", "发布第一篇小说"),
    AchDef("novel5", "📚", "连载作者", "发布 5 篇小说"),
    AchDef("draw1", "🖌️", "涂鸦第一笔", "上传第一张画作"),
    AchDef("draw10", "🧑‍🎨", "画室常客", "上传 10 张画作"),
    AchDef("meme1", "😆", "表情包居民", "上传第一张表情包"),
    AchDef("meme10", "🤪", "梗图大师", "上传 10 张表情包"),
    AchDef("daily1", "🌤️", "日常一笔", "记录第一篇日常"),
    AchDef("daily10", "📝", "日常史官", "记录 10 篇日常"),
    AchDef("column1", "📰", "专栏开张", "发布第一篇专栏"),
    AchDef("column5", "📑", "专栏作家", "发布 5 篇专栏"),
    AchDef("exchange1", "🛍️", "初次剁手", "在商城兑换第一件商品"),
    AchDef("exchange5", "🛒", "购物车常客", "累计兑换 5 件商品"),
    AchDef("exchange20", "🏪", "商城VIP", "累计兑换 20 件商品"),
    AchDef("useItem1", "🎁", "拆礼物", "使用第一件背包物品"),
    AchDef("wish1", "🌠", "许愿星", "发出第一个愿望"),
    AchDef("wish5", "✨", "愿望使者", "累计发出 5 个愿望"),
    AchDef("feedback1", "📮", "建言献策", "提交第一条反馈需求"),
    AchDef("explorer", "⚞", "网站探险家", "使用功能 + 媒记作品合计 20 次"),
    AchDef("collector", "🧰", "收藏家", "兑换商品 + 发帖合计 30"),
    AchDef("polygraph", "🌀", "全能记录者", "日常+专栏+媒记作品合计 30"),
]

/// appType / 模块 → 中文名（动态流、通知等处映射）
func appTypeName(_ key: String) -> String {
    switch key {
    case "daily": return "日常"
    case "column": return "专栏"
    case "novel": return "小说"
    case "meme": return "梗图"
    case "photo": return "壁纸"
    case "draw": return "绘画"
    case "board": return "贴板"
    case "checkin", "check_in": return "签到"
    case "feature": return "功能记录"
    case "comment": return "评论"
    case "like": return "点赞"
    case "game": return "游戏"
    case "gift", "exchange": return "商城"
    default:
        if let cat = FEATURE_CATALOG.first(where: { $0.appType == key }) {
            return cat.title
        }
        return key
    }
}

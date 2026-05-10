-- ============================================================================
-- BOSS战：蚀·虚空之女
-- 击败虫族母舰后俘虏原生者使徒
-- ============================================================================

local M = {}

M.Eclipse_BossBattle = {
    -- 剧情简介（跳过时显示）
    summary = "在与虫族母舰的决战中，指挥官遭遇了原生者的使徒——蚀。击败母舰后，蚀与母巢的精神链接断裂，陷入前所未有的孤独。指挥官向她伸出了手。",
    
    -- ========== 第一幕：战前对峙 ==========
    {
        speaker = "蚀",
        text = "……你就是那支舰队的指挥官。",
        image = "image/蚀/母巢_指挥.jpg",
        emotion = "冷漠",
    },
    {
        speaker = "蚀",
        text = "母巢对你很感兴趣。一支小小的流亡舰队，竟能在帝国和我们的夹缝中存活这么久。",
        emotion = "冷漠",
    },
    {
        speaker = "蚀",
        text = "我曾以为人类只是脆弱的个体，执着于无意义的'自我'。",
        emotion = "冷漠",
    },
    {
        speaker = "蚀",
        text = "但你不一样。你的舰长们……她们愿意为你去死。",
        emotion = "疑惑",
    },
    {
        speaker = "蚀",
        text = "为什么？",
        emotion = "疑惑",
    },
    {
        speaker = "蚀",
        text = "……算了。答案已经不重要了。",
        emotion = "冷漠",
    },
    {
        speaker = "蚀",
        text = "母巢的意志即是我的意志。你的旅途，到此为止。",
        emotion = "威严",
    },
    
    -- ========== 进入BOSS战（由游戏逻辑触发）==========
    
    -- ========== 第二幕：战败（链接断裂）==========
    {
        speaker = "蚀",
        text = "……不可能。",
        image = "image/蚀/战败_崩溃.jpg",
        emotion = "惊讶",
    },
    {
        speaker = "蚀",
        text = "我是母巢的使徒……我不会……",
        emotion = "惊讶",
    },
    {
        speaker = "蚀",
        text = "——Loss of connection detected——",
        emotion = "冷漠",
    },
    {
        speaker = "蚀",
        text = "……什么？",
        emotion = "惊讶",
    },
    {
        speaker = "蚀",
        text = "母巢……母巢的声音……消失了……",
        emotion = "绝望",
    },
    {
        speaker = "蚀",
        text = "不……回来……回答我……",
        emotion = "绝望",
    },
    {
        speaker = "蚀",
        text = "…………",
    },
    {
        speaker = "蚀",
        text = "好安静。",
        emotion = "悲伤",
    },
    {
        speaker = "蚀",
        text = "原来……这就是你们每时每刻都在承受的东西。",
        emotion = "悲伤",
    },
    {
        speaker = "蚀",
        text = "孤独。",
        emotion = "悲伤",
    },
    
    -- ========== 第三幕：被俘 ==========
    {
        speaker = "蚀",
        text = "……你为什么不动手？",
        image = "image/蚀/舰队_孤独.jpg",
        emotion = "疑惑",
    },
    {
        speaker = "蚀",
        text = "我杀了你的人。我是你的敌人。",
        emotion = "冷漠",
    },
    {
        speaker = "蚀",
        text = "……",
    },
    {
        speaker = "蚀",
        text = "你在等什么？",
        emotion = "疑惑",
    },
    {
        speaker = "",
        text = "（指挥官向蚀伸出手）",
    },
    {
        speaker = "蚀",
        text = "…………",
        image = "image/蚀/舰队_挣扎.jpg",
    },
    {
        speaker = "蚀",
        text = "我不明白。",
        emotion = "疑惑",
    },
    {
        speaker = "蚀",
        text = "我真的……不明白你们。",
        emotion = "疑惑",
    },
    
    -- ========== 第四幕：加入 ==========
    {
        speaker = "",
        text = "（蚀握住了那只手）",
    },
    {
        speaker = "蚀",
        text = "……好。",
        image = "image/蚀/舰队_不适应.jpg",
        emotion = "平静",
    },
    {
        speaker = "蚀",
        text = "既然母巢已经抛弃了我……我也没有别的地方可去。",
        emotion = "悲伤",
    },
    {
        speaker = "蚀",
        text = "但我要告诉你，指挥官。",
        emotion = "冷静",
    },
    {
        speaker = "蚀",
        text = "我不确定自己是否值得信任。",
        emotion = "冷静",
    },
    {
        speaker = "蚀",
        text = "这具身体里……有一部分不属于我。",
        emotion = "冷静",
    },
    {
        speaker = "蚀",
        text = "有时候，我会听到陌生的声音。看到不属于我的记忆。",
        emotion = "疑惑",
    },
    {
        speaker = "蚀",
        text = "我不知道'我'是谁。",
        emotion = "悲伤",
    },
    {
        speaker = "蚀",
        text = "……",
    },
    {
        speaker = "蚀",
        text = "但如果你愿意收留我，",
        image = "image/蚀/舰队_微笑.jpg",
        emotion = "温柔",
    },
    {
        speaker = "蚀",
        text = "或许……我可以找到答案。",
        emotion = "温柔",
    },
    
    -- ========== 解锁（由游戏逻辑触发）==========
}

return M

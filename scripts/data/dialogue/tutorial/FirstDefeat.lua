-- ============================================================================
-- 新手引导：首次战败
-- 星遥与零的初次联动
-- ============================================================================

local M = {}

M.Tutorial_FirstDefeat = {
    -- 剧情简介（跳过时显示）
    summary = "首次战斗失利后，星遥联系了工程专家零请求支援。零分析战况后，认为单舰作战胜率过低，决定驾驶赛博号与星遥并肩作战，帮助指挥官完成任务。",
    
    -- ========== 第一幕：战败后（星遥沮丧）==========
    {
        speaker = "星遥",
        text = "撤退成功了，但是先锋号被打得好惨......",
        image = "image/星遥/战败_沮丧.jpg",
        cropTop = 0.1,
        emotion = "悲伤",
    },
    {
        speaker = "星遥",
        text = "指挥官，对不起......我以为我们能行的。",
        emotion = "悲伤",
    },
    {
        speaker = "星遥",
        text = "果然第一次实战就遇到这种强敌，还是太勉强了啊。",
        emotion = "悲伤",
    },
    {
        speaker = "星遥",
        text = "......嗯，谢谢你不怪我。",
        emotion = "温柔",
    },
    -- ========== 第二幕：星遥振作 ==========
    {
        speaker = "星遥",
        text = "不过没关系！先锋号还没到报废的程度！",
        image = "image/星遥/战败_开心.jpg",
        cropTop = 0.1,
        emotion = "开心",
    },
    {
        speaker = "星遥",
        text = "对了指挥官，我们可以找零帮忙！",
        emotion = "开心",
    },
    {
        speaker = "星遥",
        text = "她是赛博号的舰长，工程技术超厉害的！修船什么的肯定没问题！",
        emotion = "开心",
    },
    {
        speaker = "星遥",
        text = "我来联系她——零！零！收到请回答！",
        emotion = "开心",
    },
    -- ========== 第三幕：零登场（与指挥官是旧识）==========
    {
        speaker = "零",
        text = "通讯已接入。星遥，我监测到先锋号的状态异常，发生了什么？",
        image = "image/零/冷静.jpg",
        imageDesc = "零半身像，冷静平淡的表情，赛博号舰桥背景。通用冷静/分析图",
        emotion = "冷静",
    },
    {
        speaker = "星遥",
        text = "嘿嘿......我们刚才遇到了一点小麻烦，先锋号受损了。",
        image = "image/星遥/战败_开心.jpg",
        cropTop = 0.1,
        emotion = "尴尬",
    },
    {
        speaker = "零",
        text = "根据远程扫描数据，先锋号主装甲受损率37%，推进系统效率下降至62%。这不是'小麻烦'。",
        image = "image/零/冷静.jpg",
        emotion = "冷静",
    },
    {
        speaker = "零",
        text = "指挥官也在？......了解了。你们遭遇的敌人，比预期的要强。",
        emotion = "冷静",
    },
    {
        speaker = "星遥",
        text = "好啦好啦！零你能不能别这么较真......总之，你能帮我们修一下吗？",
        image = "image/星遥/战败_开心.jpg",
        cropTop = 0.1,
        emotion = "调皮",
    },
    {
        speaker = "零",
        text = "可以。赛博号正在向你们的坐标移动。预计抵达时间：4分32秒。",
        image = "image/零/冷静.jpg",
        emotion = "冷静",
    },
    {
        speaker = "星遥",
        text = "太好了！零果然靠谱！",
        image = "image/星遥/战败_开心.jpg",
        cropTop = 0.1,
        emotion = "开心",
    },
    {
        speaker = "星遥",
        text = "等修好先锋号，我们再去找那帮家伙算账！",
        emotion = "激昂",
    },
    {
        speaker = "零",
        text = "不建议。根据战斗记录分析，敌方火力配置超出先锋号单舰应对能力。",
        image = "image/零/冷静.jpg",
        emotion = "冷静",
    },
    {
        speaker = "零",
        text = "即使完成修复，单独出击的胜率仍然只有23.7%。",
        emotion = "冷静",
    },
    {
        speaker = "星遥",
        text = "诶......那怎么办？难道就这样算了吗？",
        image = "image/星遥/战败_沮丧.jpg",
        cropTop = 0.1,
        emotion = "担忧",
    },
    {
        speaker = "零",
        text = "......有一个方案。",
        image = "image/零/疑惑.jpg",
        imageDesc = "零半身像，微微歪头思考的表情，赛博号舰桥背景。通用疑问/思考图",
        emotion = "疑惑",
    },
    {
        speaker = "零",
        text = "赛博号虽然以工程支援为主，但也具备一定的战斗能力。",
        image = "image/零/冷静.jpg",
        emotion = "冷静",
    },
    {
        speaker = "零",
        text = "如果指挥官需要，我可以和星遥一起出击。双舰协同作战，胜率可以提升到67.2%。",
        emotion = "冷静",
    },
    {
        speaker = "星遥",
        text = "哇！零你愿意一起去吗？！",
        image = "image/星遥/战败_开心.jpg",
        cropTop = 0.1,
        emotion = "惊讶",
    },
    {
        speaker = "零",
        text = "这是基于数据的合理判断。而且......",
        image = "image/零/冷静.jpg",
        emotion = "冷静",
    },
    {
        speaker = "零",
        text = "指挥官之前帮过我。现在轮到我了。",
        image = "image/零/微笑.jpg",
        imageDesc = "零半身像，嘴角微微上扬的淡淡微笑，赛博号舰桥背景。罕见的正面情绪图",
        emotion = "温柔",
    },
    {
        speaker = "星遥",
        text = "零！你刚才笑了对不对！我看到了！",
        image = "image/星遥/战败_开心.jpg",
        cropTop = 0.1,
        emotion = "开心",
    },
    {
        speaker = "零",
        text = "......只是嘴角肌肉的轻微收缩。不具备特殊含义。",
        image = "image/零/冷静.jpg",
        emotion = "冷静",
    },
    {
        speaker = "星遥",
        text = "哈哈！零就是嘴硬！",
        image = "image/星遥/战败_开心.jpg",
        cropTop = 0.1,
        emotion = "开心",
    },
    {
        speaker = "星遥",
        text = "太好了指挥官！有零加入，我们肯定能赢！",
        emotion = "激昂",
    },
    {
        speaker = "零",
        text = "赛博号即将抵达。修复完成后，随时可以出发。",
        image = "image/零/冷静.jpg",
        emotion = "冷静",
    },
    {
        speaker = "零",
        text = "指挥官，期待与你并肩作战。",
        image = "image/零/微笑.jpg",
        emotion = "温柔",
    },
}

return M

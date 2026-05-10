-- ============================================================================
-- 星河战姬 Starkyries - 数学工具函数
-- ============================================================================

local Math = {}

-- ============================================================================
-- 基础数学函数
-- ============================================================================

-- 限制值在范围内
function Math.Clamp(v, min, max)
    return v < min and min or (v > max and max or v)
end

-- 线性插值
function Math.Lerp(a, b, t)
    return a + (b - a) * t
end

-- 平滑插值 (Smoothstep)
function Math.Smoothstep(a, b, t)
    t = Math.Clamp((t - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)
end

-- 随机范围
function Math.RandomRange(min, max)
    return min + math.random() * (max - min)
end

-- 随机整数范围
function Math.RandomInt(min, max)
    return math.random(min, max)
end

-- ============================================================================
-- 2D 向量运算
-- ============================================================================

-- 2D距离
function Math.Distance(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- 3D距离
function Math.Distance3D(p1, p2)
    local dx = p2.x - p1.x
    local dy = p2.y - p1.y
    local dz = p2.z - p1.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- 向量归一化
function Math.Normalize(x, y)
    local len = math.sqrt(x * x + y * y)
    if len > 0.001 then
        return x / len, y / len
    end
    return 0, 0
end

-- 计算角度（弧度）
function Math.AngleTo(fromX, fromY, toX, toY)
    return math.atan2(toY - fromY, toX - fromX)
end

-- 弧度转角度
function Math.RadToDeg(rad)
    return rad * 180 / math.pi
end

-- 角度转弧度
function Math.DegToRad(deg)
    return deg * math.pi / 180
end

-- 向量长度
function Math.Length(x, y)
    return math.sqrt(x * x + y * y)
end

-- 向量点积
function Math.Dot(x1, y1, x2, y2)
    return x1 * x2 + y1 * y2
end

-- ============================================================================
-- 角度处理
-- ============================================================================

-- 归一化角度到 [-pi, pi]
function Math.NormalizeAngle(angle)
    while angle > math.pi do angle = angle - 2 * math.pi end
    while angle < -math.pi do angle = angle + 2 * math.pi end
    return angle
end

-- 角度差（最短路径）
function Math.AngleDiff(from, to)
    local diff = to - from
    return Math.NormalizeAngle(diff)
end

-- 平滑旋转
function Math.LerpAngle(from, to, t)
    local diff = Math.AngleDiff(from, to)
    return from + diff * t
end

-- ============================================================================
-- 碰撞检测
-- ============================================================================

-- 获取实体的有效碰撞半径
-- entity: 实体对象（需要有 hitRadius 或 scale 属性）
-- compensation: 补偿系数（默认使用 Settings.Combat.EdgeDistanceCompensation）
-- 返回: 有效半径
function Math.GetEntityRadius(entity, compensation)
    -- 延迟加载 Settings（避免循环依赖）
    local Settings = require("config.settings")
    compensation = compensation or Settings.Combat.EdgeDistanceCompensation
    return (entity.hitRadius or entity.scale or 0) * compensation
end

-- 计算到实体边缘的距离
-- centerDist: 到实体中心的距离
-- entity: 实体对象
-- compensation: 补偿系数（可选）
-- 返回: edgeDist（边缘距离）, entityRadius（实体有效半径）
function Math.EdgeDistance(centerDist, entity, compensation)
    local entityRadius = Math.GetEntityRadius(entity, compensation)
    local edgeDist = centerDist - entityRadius
    return edgeDist, entityRadius
end

-- 计算两点间到实体边缘的距离
-- x, y: 起点坐标
-- entity: 目标实体
-- compensation: 补偿系数（可选）
-- 返回: edgeDist（边缘距离）, centerDist（中心距离）, entityRadius（有效半径）
function Math.EdgeDistanceTo(x, y, entity, compensation)
    local pos = entity.node and entity.node.position
    if not pos then return 999, 999, 0 end
    
    local centerDist = Math.Distance(x, y, pos.x, pos.y)
    local edgeDist, entityRadius = Math.EdgeDistance(centerDist, entity, compensation)
    return edgeDist, centerDist, entityRadius
end

-- 圆形碰撞检测
function Math.CircleCollision(x1, y1, r1, x2, y2, r2)
    local dist = Math.Distance(x1, y1, x2, y2)
    return dist < (r1 + r2)
end

-- 点是否在矩形内
function Math.PointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- 点是否在圆内
function Math.PointInCircle(px, py, cx, cy, r)
    return Math.Distance(px, py, cx, cy) <= r
end

-- ============================================================================
-- 随机工具
-- ============================================================================

-- 打乱表
function Math.ShuffleTable(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- 从表中随机选择
function Math.RandomChoice(t)
    if #t == 0 then return nil end
    return t[math.random(#t)]
end

-- 权重随机选择
function Math.WeightedRandom(items, weights)
    local totalWeight = 0
    for i, w in ipairs(weights) do
        totalWeight = totalWeight + w
    end
    
    local roll = math.random() * totalWeight
    local cumWeight = 0
    
    for i, w in ipairs(weights) do
        cumWeight = cumWeight + w
        if roll <= cumWeight then
            return items[i], i
        end
    end
    
    return items[#items], #items
end

-- ============================================================================
-- 缓动函数
-- ============================================================================

-- 二次缓入
function Math.EaseInQuad(t)
    return t * t
end

-- 二次缓出
function Math.EaseOutQuad(t)
    return t * (2 - t)
end

-- 二次缓入缓出
function Math.EaseInOutQuad(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return -1 + (4 - 2 * t) * t
    end
end

-- 弹性缓出
function Math.EaseOutElastic(t)
    if t == 0 or t == 1 then return t end
    local p = 0.3
    local s = p / 4
    return math.pow(2, -10 * t) * math.sin((t - s) * (2 * math.pi) / p) + 1
end

-- 弹跳缓出
function Math.EaseOutBounce(t)
    if t < 1 / 2.75 then
        return 7.5625 * t * t
    elseif t < 2 / 2.75 then
        t = t - 1.5 / 2.75
        return 7.5625 * t * t + 0.75
    elseif t < 2.5 / 2.75 then
        t = t - 2.25 / 2.75
        return 7.5625 * t * t + 0.9375
    else
        t = t - 2.625 / 2.75
        return 7.5625 * t * t + 0.984375
    end
end

return Math

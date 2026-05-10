# 工具

本目录保存Brotato公开资料快照的可重复脚本。

| 脚本 | 用途 |
|---|---|
| `sync_brotato_wiki.py` | 抓取Wiki原始模板、核心页面和主要属性页面，生成JSON与CSV |
| `fetch_brotato_entity_pages.py` | 抓取角色/武器/道具/Elite/Boss单页，抽取章节和Notes |
| `verify_brotato_snapshot.py` | 校验当前快照计数、CSV行数、商店公式、敌人口径、实体页结果 |

默认校验命令：

```bash
/Users/dash/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 docs/Brotato原作参考/工具/verify_brotato_snapshot.py
```

期望结果：`ok: true`。

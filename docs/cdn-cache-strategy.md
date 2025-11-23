# CDN 缓存策略 - SSG 站点

## 概述

你的站点是 **Static Site Generation (SSG)**，所有内容在构建时生成，非常适合 CDN 缓存。

## 当前性能瓶颈

```
无 CDN 状态:
- 总耗时: 1.074s (HTTP/2)
- TTFB: 0.607s (网络延迟)
- 下载: 0.467s (低带宽)
- 有效速度: 只有 128KB/s (1Mbps)
```

## CDN 缓存策略

### 方案 1: 保守策略（默认配置）

**适合场景：** 开始使用 CDN，不确定缓存策略

**配置：**
```
Cloudflare 默认设置（不用改）
- HTML: 不缓存（每次回源）
- CSS/JS: 缓存
- 图片/字体: 缓存
```

**效果：**
- 提速 82-85%
- 首次访问: 1.074s → 0.19s
- 更新后立即生效（HTML 不缓存）

**缺点：**
- 每次访问都需要回源获取 HTML
- CDN 回源请求数较多

---

### 方案 2: 激进策略（推荐 SSG）

**适合场景：** 静态站点，更新不频繁

**配置：**

#### 1. 修改 Caddyfile

```caddy
(ssg_cache) {
    import common_cache

    # HTML 缓存 1 小时（CDN），浏览器验证
    @html path *.html / /*/
    header @html Cache-Control "public, max-age=0, s-maxage=3600, must-revalidate"
    #                                    ↑           ↑
    #                         浏览器每次验证  CDN缓存1小时
}
```

#### 2. Cloudflare Page Rules

```
URL: owen-blog-demo.owenyoung.com/*

Settings:
✅ Cache Level: Cache Everything
✅ Edge Cache TTL: 1 hour
✅ Browser Cache TTL: Respect Existing Headers
```

**效果：**
- 提速 90%
- 首次访问: 1.074s → 0.19s
- 后续访问: 1.074s → 0.10s
- 更新后 1 小时内生效（或手动清除 CDN 缓存）

**优点：**
- 性能最佳
- 减少回源请求
- 降低服务器负载

**缺点：**
- 部署后需要清除 CDN 缓存

---

### 方案 3: 平衡策略（实际推荐）

**适合场景：** 平衡性能和更新速度

**配置：**

```caddy
(ssg_cache) {
    import common_cache

    # HTML 缓存 5 分钟
    @html path *.html / /*/
    header @html Cache-Control "public, max-age=60, s-maxage=300, stale-while-revalidate=600"
    #                                    ↑          ↑              ↑
    #                          浏览器1分钟  CDN 5分钟   过期后还能用10分钟
}
```

**效果：**
- 提速 85-90%
- 部署后 5 分钟自动生效
- 即使过期，仍可返回旧版本（stale-while-revalidate）

**推荐指数：⭐⭐⭐⭐⭐**

---

## 部署流程

### 初始设置（一次性）

1. **Cloudflare DNS**
   ```
   owen-blog-demo.owenyoung.com
   类型: A / CNAME
   代理状态: 已代理（橙色云朵）✅
   ```

2. **Cloudflare 设置**
   - Speed → Optimization
     - ✅ Auto Minify: JavaScript, CSS, HTML
     - ✅ Brotli 压缩
     - ✅ Early Hints

   - Caching → Configuration
     - ✅ Caching Level: Standard
     - ✅ Browser Cache TTL: Respect Existing Headers

3. **Page Rules（可选，用于激进策略）**
   ```
   URL: *owen-blog-demo.owenyoung.com/*

   Settings:
   - Cache Level: Cache Everything
   - Edge Cache TTL: 5 minutes
   ```

### 日常部署流程

```bash
# 1. 构建和部署站点
pnpm build
ansible-playbook ansible/playbooks/deploy-infra-owen-blog.yml

# 2. 清除 CDN 缓存（如果使用激进策略）
# 方法1: Cloudflare 控制台
#   Caching → Purge Cache → Purge Everything

# 方法2: Cloudflare API
curl -X POST "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/purge_cache" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}'
```

---

## 测试 CDN 效果

```bash
# 测试是否通过 CDN
curl -I https://owen-blog-demo.owenyoung.com/quotes/ | grep -i 'cf-'

# 应该看到：
# cf-cache-status: HIT / MISS / DYNAMIC
# cf-ray: xxxxx
# server: cloudflare

# 性能测试
./scripts/test-performance.sh
```

**预期结果：**
- 总耗时: 1.074s → 0.2-0.3s
- TTFB: 0.607s → 0.05-0.10s
- cf-cache-status: HIT (缓存命中)

---

## 缓存失效策略

### 自动失效（推荐）

使用短 TTL (5-15分钟)，无需手动清除：

```caddy
header @html Cache-Control "public, max-age=60, s-maxage=300"
```

### 手动失效

部署后手动清除：

```bash
# Cloudflare 控制台
Caching → Purge Cache → Custom Purge

# 只清除特定页面
https://owen-blog-demo.owenyoung.com/quotes/
```

### 版本化资源（最佳实践）

JS/CSS 使用哈希文件名（构建工具自动生成）：
```html
<link rel="stylesheet" href="/assets/main.abc123.css">
<script src="/assets/app.def456.js"></script>
```

这样可以：
- 永久缓存静态资源
- 更新后自动失效（文件名变化）

---

## 常见问题

### Q: HTML 缓存会导致用户看到旧内容吗？

**A:** 不会，如果配置正确：

```caddy
# 浏览器每次验证，CDN 缓存短时间
Cache-Control "public, max-age=0, s-maxage=300, must-revalidate"
```

流程：
1. 用户请求 → 浏览器发送请求到 CDN
2. CDN 检查缓存是否过期（5分钟）
3. 如果过期 → 回源验证 → 返回最新内容
4. 如果未过期 → 直接返回缓存

### Q: 部署后如何立即看到更新？

**方法 1:** 强制刷新浏览器
```
Mac: Cmd + Shift + R
Windows: Ctrl + Shift + R
```

**方法 2:** 清除 CDN 缓存
```
Cloudflare 控制台 → Purge Cache
```

**方法 3:** 使用查询参数
```
https://owen-blog-demo.owenyoung.com/quotes/?v=20251123
```

### Q: 哪些内容应该缓存，哪些不应该？

**应该缓存（你的站点全部是）：**
- ✅ HTML (SSG 生成)
- ✅ CSS/JS
- ✅ 图片/字体
- ✅ 所有静态资源

**不应该缓存：**
- ❌ API 响应（动态数据）
- ❌ 用户相关内容（个性化）
- ❌ 实时数据

你的站点是纯 SSG，所有内容都可以缓存！

---

## 推荐配置总结

**立即实施（0 风险）：**
1. ✅ 启用 Cloudflare 代理（橙色云朵）
2. ✅ 使用默认设置

**效果：** 提速 82%，HTML 不缓存

---

**进阶优化（推荐）：**
1. ✅ 修改 Caddyfile 缓存头（5分钟 TTL）
2. ✅ 可选：添加 Page Rules

**效果：** 提速 90%，5分钟后自动更新

---

## 监控和日志

查看 CDN 命中率：

```bash
# Cloudflare Analytics
Caching → Analytics → Cache Performance

关键指标:
- Cache Hit Ratio: 目标 > 80%
- Bandwidth Saved: 目标 > 70%
- Requests: 观察流量分布
```

查看 Caddy 日志：
```bash
docker logs caddy --tail 100 | jq 'select(.msg == "handled request") | {uri, status, duration}'
```

---

## 结论

对于你的 SSG 站点：

✅ **HTML 可以且应该被 CDN 缓存**
✅ **即使不缓存 HTML，CDN 也能提速 85%**
✅ **推荐使用短 TTL (5-15分钟) 平衡性能和更新速度**
✅ **预期效果：1.074s → 0.2-0.3s (提升 70-80%)**

下一步：启用 Cloudflare 代理，享受免费的全球 CDN 加速！

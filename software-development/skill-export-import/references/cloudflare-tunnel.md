# Cloudflare Tunnel 临时公网暴露

用于将本地服务（如 WebUI）快速暴露到公网，无需 Cloudflare 账号。

## 下载 cloudflared
```bash
cd /tmp
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
chmod +x cloudflared
```

## 启动隧道
```bash
/tmp/cloudflared tunnel --url http://localhost:5173
```

## 输出示例
```
Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):
https://xxxx-xxxx-xxxx.trycloudflare.com
```

## 注意事项
- **临时隧道无 uptime 保证**，仅供测试使用
- 每次重启会生成不同的 URL
- 生产环境应使用命名的 Cloudflare Tunnel

## 生产级方案
1. 创建 Cloudflare 账号
2. 创建命名隧道：`cloudflared tunnel create <name>`
3. 配置 `~/.cloudflared/config.yml`
4. 获得固定公网 URL

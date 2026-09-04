# K-Dense BYOK — Docker 容器

为 [K-Dense BYOK](https://github.com/K-Dense-AI/k-dense-byok) 项目提供的 Docker 容器化方案，支持 GPU 直通，可直接运行 Kady 科研助手。

## 前置要求

- **Docker Engine** ≥ 24（含 `docker compose` 插件）
- 可选 GPU：**NVIDIA Container Toolkit** ≥ 1.15（[安装指南](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)）

## 快速开始

### 1. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env，填入你的 API keys
```

### 2. 构建镜像

```bash
# 使用 pixi（推荐）
pixi run build

# 或直接使用 docker compose
docker compose build
```

首次构建会下载所有 npm 依赖和 Chromium 浏览器，耗时约 5-10 分钟。

### 3. 启动容器

**CPU 模式：**
```bash
pixi run up
# 等效于: docker compose up -d
```

**GPU 模式（需 NVIDIA Container Toolkit）：**
```bash
pixi run up-gpu
# 等效于: docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d
```

**GPU + Ollama 本地模型：**
```bash
pixi run up-gpu-ollama
# 然后设置 OLLAMA_BASE_URL=http://ollama:11434
```

### 4. 访问

浏览器打开 [http://localhost:3000](http://localhost:3000)

**首次启动说明：** 容器启动时会：
1. 重新校验 npm 依赖（已预先安装，增量极快）
2. 下载科学技能目录（需联网）
3. 编译 TypeScript 后端
4. 启动 Fastify 后端（端口 8000）和 Next.js 前端（端口 3000）

整个过程约 30-90 秒，见控制台日志或等待 healthcheck 通过。

## 数据持久化

容器使用两具命名卷持久化重要数据：

| 卷 | 挂载点 | 内容 |
|---|---|---|
| `kady-projects` | `/app/projects` | 项目文件、对话、笔记 |
| `kady-home` | `/root/.kady` | Pi 认证凭证（OAuth tokens）、设置、技能缓存 |

这些卷在 `docker compose down` 后保留，升级镜像不影响已有数据。

## GPU 支持

### 原理

参考 [Claude-Science-Container](https://github.com/SilenWang/Claude-Science-Container) 项目的实现，使用 **CDI（Container Device Interface）** 进行 GPU 直通：

```yaml
# docker-compose.gpu.yml
services:
  kady:
    devices:
      - nvidia.com/gpu=all
```

CDI 会自动将 `/dev/nvidia*` 设备、`nvidia-smi` 工具和 CUDA 运行时库注入容器。Kady 的系统监视器会自动检测 GPU 活动。

### 验证 GPU 是否生效

```bash
docker compose exec kady nvidia-smi -L
```

如果不使用 GPU，系统监视器跳过 GPU 检测，应用正常运行。

### Ollama 侧边容器

`docker-compose.gpu.yml` 包含一个可选的 Ollama 服务（`--profile ollama`），它共享 GPU 并将模型存储在 `ollama-data` 卷中。使用时：

```bash
# .env 中设置:
OLLAMA_BASE_URL=http://ollama:11434

# 启动（包括 Ollama 侧边容器）:
pixi run up-gpu-ollama
```

## 配置参考

所有配置通过 `.env` 文件传递，支持以下关键变量：

| 变量 | 默认值 | 说明 |
|---|---|---|
| `OPENROUTER_API_KEY` | — | OpenRouter API 密钥 |
| `NVIDIA_API_KEY` | — | NVIDIA NIM API 密钥 |
| `OLLAMA_BASE_URL` | `http://host.docker.internal:11434` | Ollama 端点 |
| `DEFAULT_MODEL_ID` | `anthropic/claude-opus-5` | 默认模型 ID |
| `DEFAULT_MODEL_PROVIDER` | `openrouter` | 默认模型提供商 |
| `KADY_UI_PORT` | `3000` | 前端端口映射 |
| `KADY_API_PORT` | `8000` | 后端端口映射 |
| `HTTP_PROXY` / `HTTPS_PROXY` | — | 企业代理 |

完整变量列表见上游的 [.env.example](https://github.com/K-Dense-AI/k-dense-byok/blob/main/.env.example)。

## 常用命令

```bash
# 查看日志
pixi run logs

# 停止容器
pixi run down

# 查看状态
pixi run ps

# 重启
pixi run restart
```

## 故障排查

### Chrome/Chromium 沙箱警告

容器以 root 运行，Playwright 的 chromium 可能需要 `--no-sandbox`。pi-web-access 包通常自动处理此问题；若遇到浏览器启动失败，检查容器日志。

### GPU 不可见

1. 确认主机已安装 NVIDIA Container Toolkit
2. 确认使用 GPU 覆盖文件启动：`docker compose -f docker-compose.yml -f docker-compose.gpu.yml ...`
3. 验证：`docker compose exec kady nvidia-smi -L`
4. 如果没有 `docker-compose.gpu.yml`，Kady 在 CPU 模式下正常运行

### 端口冲突

默认端口 3000/8000 被占用时，在 `.env` 中设置：
```
KADY_UI_PORT=3001
KADY_API_PORT=8001
```

### 网络问题（代理环境）

在 `.env` 中设置 `HTTP_PROXY` / `HTTPS_PROXY`，Node.js 会通过 proxy-agent 自动使用它们。

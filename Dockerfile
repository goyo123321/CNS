# 构建阶段 - 使用多阶段构建减小镜像大小
FROM golang:1.21-alpine AS builder

WORKDIR /app

# 安装必要的构建工具
RUN apk add --no-cache git make

# 复制 Go 模块文件并下载依赖
COPY go.mod go.sum ./
RUN go mod download

# 复制所有 Go 源文件
COPY *.go ./

# 构建静态链接的二进制文件（减小体积，提高兼容性）
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a \
    -ldflags="-w -s -extldflags '-static'" \
    -installsuffix cgo \
    -o cns .

# 运行阶段 - 使用最小化的基础镜像
FROM alpine:latest

# 安装运行时依赖
RUN apk --no-cache add \
    ca-certificates \
    tzdata \
    && update-ca-certificates

# 创建应用用户和目录
RUN adduser -D -u 1000 -s /bin/sh appuser && \
    mkdir -p /app /config /logs && \
    chown -R appuser:appuser /app /config /logs

WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder --chown=appuser:appuser /app/cns .
COPY --chown=appuser:appuser config.json .

# 切换到非root用户
USER appuser

# 暴露端口（与配置文件中一致）
EXPOSE 8000

# 健康检查 - 使用更可靠的检查方式
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD netstat -ltn | grep -q 8000 || exit 1

# 设置容器信号处理
STOPSIGNAL SIGTERM

# 启动应用（使用绝对路径）
ENTRYPOINT ["./cns"]
CMD ["-json", "config.json"]

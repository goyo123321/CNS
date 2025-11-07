# 构建阶段
FROM golang:1.21-alpine AS builder

WORKDIR /app

# 安装必要的工具
RUN apk add --no-cache git curl wget

# 方法1: 直接从 GitHub 获取 CNS 源码并构建
RUN git clone https://github.com/mmmdbybyd/CNS.git . && \
    git checkout v0.4.2

# 构建二进制文件
RUN CGO_ENABLED=0 GOOS=linux go build -a \
    -ldflags="-w -s -extldflags '-static'" \
    -installsuffix cgo \
    -o cns .

# 可选: 使用 UPX 压缩（减小体积）
RUN wget https://github.com/upx/upx/releases/download/v4.0.2/upx-4.0.2-amd64_linux.tar.xz && \
    tar -xf upx-4.0.2-amd64_linux.tar.xz && \
    ./upx-4.0.2-amd64_linux/upx --best cns

# 运行阶段
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/cns .

# 创建配置目录和文件
RUN mkdir -p /etc/cns
COPY config.json /etc/cns/

# 创建非root用户
RUN adduser -D -u 1000 appuser && \
    chown -R appuser:appuser /app /etc/cns

USER appuser

# 环境变量配置
ENV CNS_PORT=8000
ENV CNS_TLS_PORT=""
ENV CNS_ENCRYPT_PASSWORD=""
ENV CNS_UDP_FLAG="httpUDP"
ENV CNS_PROXY_KEY="Host"

EXPOSE $CNS_PORT

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 -O- http://localhost:${CNS_PORT:-8000}/health || exit 1

# 启动脚本（处理环境变量）
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

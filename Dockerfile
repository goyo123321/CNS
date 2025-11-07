# 构建阶段
FROM golang:1.21-alpine AS builder

WORKDIR /app

# 安装必要的工具
RUN apk add --no-cache git

# 直接从 GitHub 获取 CNS 源码并构建
RUN git clone https://github.com/mmmdbybyd/CNS.git . && \
    git checkout v0.4.2

# 构建二进制文件
RUN CGO_ENABLED=0 GOOS=linux go build -a \
    -ldflags="-w -s -extldflags '-static'" \
    -installsuffix cgo \
    -o cns .

# 运行阶段
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/cns .

# 创建启动脚本，支持环境变量配置
RUN cat > /start.sh << 'EOF'
#!/bin/sh
set -e

# 从环境变量生成配置文件
CONFIG_FILE="/tmp/cns-config.json"

# 构建 TLS 配置
TLS_CONFIG="[]"
if [ -n "$CNS_TLS_PORT" ]; then
    TLS_CONFIG="[\"$CNS_TLS_PORT\"]"
fi

# 生成配置文件
cat > $CONFIG_FILE << CONFIGEOF
{
    "Tls": {
        "Listen_addr": $TLS_CONFIG,
        "Certificate_path": "",
        "Key_path": ""
    },
    "Listen_addr": [
        ":${CNS_PORT:-8000}"
    ],
    "Proxy_key": "${CNS_PROXY_KEY:-Host}",
    "Udp_flag": "${CNS_UDP_FLAG:-httpUDP}",
    "Encrypt_password": "${CNS_ENCRYPT_PASSWORD:-}",
    "Pid_path": "/tmp/cns.pid",
    "Tcp_timeout": 600,
    "Udp_timeout": 30,
    "Enable_dns_tcpOverUdp": ${CNS_ENABLE_DNS_TCP_OVER_UDP:-false},
    "Enable_httpDNS": ${CNS_ENABLE_HTTP_DNS:-true},
    "Enable_TFO": ${CNS_ENABLE_TFO:-false}
}
CONFIGEOF

echo "Starting CNS server with config:"
echo "Port: ${CNS_PORT:-8000}"
echo "TLS Port: ${CNS_TLS_PORT:-disabled}"
echo "Encryption: ${CNS_ENCRYPT_PASSWORD:+enabled}"
echo "Proxy Key: ${CNS_PROXY_KEY:-Host}"
echo "UDP Flag: ${CNS_UDP_FLAG:-httpUDP}"

# 启动 CNS
exec /app/cns -json $CONFIG_FILE
EOF

RUN chmod +x /start.sh

# 创建非root用户
RUN adduser -D -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

# 环境变量配置
ENV CNS_PORT=8000
ENV CNS_TLS_PORT="443"
ENV CNS_ENCRYPT_PASSWORD="12332100"
ENV CNS_UDP_FLAG="httpUDP"
ENV CNS_PROXY_KEY="Host"
ENV CNS_ENABLE_DNS_TCP_OVER_UDP="false"
ENV CNS_ENABLE_HTTP_DNS="true"
ENV CNS_ENABLE_TFO="false"

EXPOSE $CNS_PORT

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 -O- http://localhost:${CNS_PORT}/health 2>/dev/null || exit 1

ENTRYPOINT ["/start.sh"]

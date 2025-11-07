# 构建阶段
FROM golang:1.21-alpine AS builder

# 定义构建参数
ARG CNS_VERSION=v0.4.2

WORKDIR /app

# 安装 wget 用于下载文件
RUN apk add --no-cache wget

# 下载完整的 CNS 项目文件（使用构建参数）
RUN wget -q https://raw.githubusercontent.com/mmmdbybyd/CNS/${CNS_VERSION}/cns.go && \
    wget -q https://raw.githubusercontent.com/mmmdbybyd/CNS/${CNS_VERSION}/network_tunnel.go && \
    wget -q https://raw.githubusercontent.com/mmmdbybyd/CNS/${CNS_VERSION}/tls_server.go && \
    wget -q https://raw.githubusercontent.com/mmmdbybyd/CNS/${CNS_VERSION}/utils.go && \
    wget -q https://raw.githubusercontent.com/mmmdbybyd/CNS/${CNS_VERSION}/crypt.go && \
    wget -q https://raw.githubusercontent.com/mmmdbybyd/CNS/${CNS_VERSION}/go.mod && \
    wget -q https://raw.githubusercontent.com/mmmdbybyd/CNS/${CNS_VERSION}/go.sum

# 复制本地配置文件
COPY config.json ./

# 下载依赖
RUN go mod download

# 构建二进制文件
RUN CGO_ENABLED=0 GOOS=linux go build -a \
    -ldflags="-w -s -extldflags '-static'" \
    -installsuffix cgo \
    -o cns .

# 运行阶段
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata

RUN adduser -D -u 1000 appuser

WORKDIR /app

# 从构建阶段复制文件
COPY --from=builder --chown=appuser:appuser /app/cns .
COPY --from=builder --chown=appuser:appuser /app/config.json .

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD netstat -ltn | grep -q 8000 || exit 1

ENTRYPOINT ["./cns"]
CMD ["-json", "config.json"]

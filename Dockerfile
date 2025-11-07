# 构建阶段
FROM golang:1.21-alpine AS builder

WORKDIR /app

# 安装 Git
RUN apk add --no-cache git

# 克隆完整的 CNS 项目
RUN git clone https://github.com/mmmdbybyd/CNS.git . && \
    git checkout v0.4.2  # 使用特定版本，确保稳定性

# 下载依赖
RUN go mod download

# 复制本地配置文件（如果存在）
COPY config.json ./

# 构建静态二进制文件
RUN CGO_ENABLED=0 GOOS=linux go build -a \
    -ldflags="-w -s -extldflags '-static'" \
    -installsuffix cgo \
    -o cns .

# 运行阶段
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata

RUN adduser -D -u 1000 appuser

WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder --chown=appuser:appuser /app/cns .
COPY --chown=appuser:appuser config.json ./

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD netstat -ltn | grep -q 8000 || exit 1

ENTRYPOINT ["./cns"]
CMD ["-json", "config.json"]

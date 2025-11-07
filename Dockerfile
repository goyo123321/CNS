# 构建阶段
FROM golang:1.21-alpine AS builder

WORKDIR /app

# 复制 Go 模块文件
COPY go.mod go.sum ./
RUN go mod download

# 复制所有 Go 源文件
COPY *.go ./

# 构建静态二进制文件
RUN CGO_ENABLED=0 GOOS=linux go build -a \
    -ldflags="-w -s -extldflags '-static'" \
    -installsuffix cgo \
    -o cns .

# 运行阶段
FROM alpine:latest

# 安装运行时依赖
RUN apk --no-cache add ca-certificates tzdata

# 创建应用用户
RUN adduser -D -u 1000 appuser

WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder --chown=appuser:appuser /app/cns .
COPY --chown=appuser:appuser config.json .

# 切换到非root用户
USER appuser

# 暴露端口
EXPOSE 8000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD netstat -ltn | grep -q 8000 || exit 1

# 启动应用
ENTRYPOINT ["./cns"]
CMD ["-json", "config.json"]

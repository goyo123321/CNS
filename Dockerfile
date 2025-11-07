# 构建阶段
FROM golang:1.21-alpine AS builder

WORKDIR /app

# 复制源代码并构建
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o cns cns.go

# 运行阶段
FROM alpine:latest

RUN apk --no-cache add ca-certificates wget

WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/cns .
COPY config.json .

# 创建非root用户
RUN adduser -D -u 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

# 暴露端口
EXPOSE 8000

# 健康检查 - 由于cns可能没有/health端点，使用更通用的检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD netstat -ltn | grep -c 8000 || exit 1

# 启动应用
CMD ["./cns", "-json", "config.json"]

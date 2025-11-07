# 构建阶段
FROM golang:1.21-alpine AS builder

WORKDIR /app

# 复制所有 Go 源文件
COPY *.go ./
COPY go.mod ./
COPY go.sum ./

# 复制配置文件
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
COPY --chown=appuser:appuser config.json ./

USER appuser

# 暴露端口（支持环境变量覆盖）
ENV PORT=8000
EXPOSE $PORT

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 -O- http://localhost:${PORT:-8000}/health || exit 1

ENTRYPOINT ["./cns"]
CMD ["-json", "config.json"]

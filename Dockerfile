# 构建阶段
FROM golang:1.21-alpine AS builder

WORKDIR /app

# 下载依赖
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码并构建
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o cns cns.go

# 运行阶段
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# 从构建阶段复制二进制文件
COPY --from=builder /app/cns .

# 创建非root用户
RUN adduser -D -u 1000 appuser
USER appuser

# 暴露端口（与Python版本保持一致）
EXPOSE 8000

# 健康检查（使用8000端口）
HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8000/health || exit 1

# 启动应用
CMD ["./cns"]

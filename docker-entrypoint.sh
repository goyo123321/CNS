#!/bin/sh
set -e

# 如果配置文件不存在，从环境变量生成
if [ ! -f /etc/cns/config.json ]; then
    cat > /etc/cns/config.json << EOF
{
    "Tls": {
        "Listen_addr": [${CNS_TLS_PORT:+"\"$CNS_TLS_PORT\""}],
        "Certificate_path": "",
        "Key_path": ""
    },
    "Listen_addr": [
        ":${CNS_PORT:-8000}"
    ],
    "Proxy_key": "${CNS_PROXY_KEY:-Host}",
    "Udp_flag": "${CNS_UDP_FLAG:-httpUDP}",
    "Encrypt_password": "${CNS_ENCRYPT_PASSWORD}",
    "Pid_path": "/tmp/cns.pid",
    "Tcp_timeout": 600,
    "Udp_timeout": 30,
    "Enable_dns_tcpOverUdp": false,
    "Enable_httpDNS": true,
    "Enable_TFO": false
}
EOF
fi

# 启动 CNS
exec /app/cns -json /etc/cns/config.json

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

type JsonConfig struct {
	Tls                                               TlsServer
	Listen_addr                                       []string
	Proxy_key, Udp_flag, Encrypt_password, Pid_path   string
	Tcp_timeout, Udp_timeout                          time.Duration
	Enable_dns_tcpOverUdp, Enable_httpDNS, Enable_TFO bool
}

type TlsServer struct {
	Listen_addr      []string
	Certificate_path string
	Key_path         string
}

var config = JsonConfig{
	Proxy_key:   "Host",
	Udp_flag:    "httpUDP",
	Tcp_timeout: 600,
	Udp_timeout: 30,
}

var CuteBi_XorCrypt_password []byte

func jsonLoad(filename string, v *JsonConfig) {
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		log.Fatal(err)
		return
	}
	err = json.Unmarshal(data, v)
	if err != nil {
		log.Fatal(err)
		return
	}
}

func pidSaveToFile(pidPath string) {
	fp, err := os.Create(pidPath)
	if err != nil {
		fmt.Println(err)
		return
	}
	fp.WriteString(fmt.Sprintf("%d", os.Getpid()))
	fp.Close()
}

func handleCmd() {
	var (
		jsonConfigPath string
		help           bool
	)

	flag.StringVar(&jsonConfigPath, "json", "", "json config path")
	flag.BoolVar(&help, "h", false, "")
	flag.BoolVar(&help, "help", false, "display this message")

	flag.Parse()
	if help == true {
		fmt.Println("CuteBi Network Server - Docker Version")
		flag.Usage()
		os.Exit(0)
	}
	if jsonConfigPath == "" {
		// 如果没有指定配置文件，使用默认配置
		fmt.Println("No config file specified, using defaults")
		config.Listen_addr = []string{":8000"}
	} else {
		jsonLoad(jsonConfigPath, &config)
	}

	config.Enable_httpDNS = true
	config.Proxy_key = "\n" + config.Proxy_key + ": "
	CuteBi_XorCrypt_password = []byte(config.Encrypt_password)
	config.Tcp_timeout *= time.Second
	config.Udp_timeout *= time.Second
}

func setsid() {
	// 在容器环境中，setsid 可能不需要
}

func setMaxNofile() {
	// 在容器环境中，文件描述符限制由容器运行时管理
}

func initProcess() {
	log.SetFlags(log.Ldate | log.Ltime | log.Lshortfile)
	handleCmd()
	signal.Ignore(syscall.SIGPIPE)
}

func (t *TlsServer) makeCertificateConfig() {
	// 简化版 TLS 配置
}

func (t *TlsServer) startTls(addr string) {
	// 简化版 TLS 服务器
	log.Printf("TLS server would start on %s (not implemented)", addr)
}

func startHttpTunnel(addr string) {
	log.Printf("Starting HTTP tunnel on %s", addr)
	
	// 创建简单的 HTTP 服务器
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "CNS Server is running\n")
		fmt.Fprintf(w, "Time: %s\n", time.Now().Format(time.RFC3339))
		fmt.Fprintf(w, "Remote: %s\n", r.RemoteAddr)
	})
	
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})
	
	http.HandleFunc("/status", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":    "running",
			"version":   "0.4.2-docker",
			"timestamp": time.Now().Unix(),
		})
	})

	log.Printf("Server starting on %s", addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func main() {
	fmt.Printf("\n===== Application Startup at %s =====\n\n", time.Now().Format("2006-01-02 15:04:05"))
	
	initProcess()
	
	if config.Pid_path != "" {
		pidSaveToFile(config.Pid_path)
	}
	
	if len(config.Tls.Listen_addr) > 0 {
		config.Tls.makeCertificateConfig()
		for i := len(config.Tls.Listen_addr) - 1; i >= 0; i-- {
			go config.Tls.startTls(config.Tls.Listen_addr[i])
		}
	}
	
	// 如果没有配置监听地址，使用默认值
	if len(config.Listen_addr) == 0 {
		config.Listen_addr = []string{":8000"}
	}
	
	for i := len(config.Listen_addr) - 1; i >= 0; i-- {
		go startHttpTunnel(config.Listen_addr[i])
	}
	
	log.Printf("CNS Server started successfully on ports: %v", config.Listen_addr)
	log.Printf("Health check available at: http://localhost%s/health", config.Listen_addr[0])
	
	// 保持程序运行
	select {}
}

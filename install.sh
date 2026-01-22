#!/bin/bash
# 青龙面板一键安装脚本（无需管理员权限）
# GitHub: https://github.com/你的用户名/qinglong-install

set -e  # 遇到错误退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}>>>${NC} $1"
}

# 打印标题
print_header() {
    echo -e "${CYAN}"
    echo "========================================="
    echo "  青龙面板一键安装脚本 v1.0"
    echo "  无需管理员权限 | 全自动安装"
    echo "========================================="
    echo -e "${NC}"
}

# 打印完成信息
print_footer() {
    echo -e "${CYAN}"
    echo "========================================="
    echo "  安装完成！"
    echo "========================================="
    echo -e "${NC}"
}

# 检查网络连接
check_network() {
    log_step "检查网络连接..."
    
    if ! curl -s --connect-timeout 10 https://github.com > /dev/null; then
        log_warn "GitHub 访问较慢，将使用镜像源"
        export USE_MIRROR=1
    else
        log_info "网络连接正常"
    fi
}

# 安装系统依赖（用户空间）
install_deps() {
    log_step "安装系统依赖..."
    
    # 检查并安装必要的工具
    local tools="wget curl tar"
    local missing_tools=""
    
    for tool in $tools; do
        if ! command -v $tool &> /dev/null; then
            missing_tools="$missing_tools $tool"
        fi
    done
    
    if [ -n "$missing_tools" ]; then
        log_warn "缺少工具:$missing_tools"
        log_info "尝试从网络下载二进制版本..."
        
        # 创建用户bin目录
        mkdir -p ~/bin
        
        # 下载wget（如果缺失）
        if ! command -v wget &> /dev/null; then
            log_info "下载 wget..."
            wget_arch=$(uname -m)
            if [ "$wget_arch" = "x86_64" ]; then
                wget_bin_url="https://github.com/moparisthebest/static-curl/releases/download/v7.88.1/wget-amd64"
            else
                wget_bin_url="https://github.com/moparisthebest/static-curl/releases/download/v7.88.1/wget-aarch64"
            fi
            curl -L -o ~/bin/wget $wget_bin_url
            chmod +x ~/bin/wget
            export PATH="$HOME/bin:$PATH"
        fi
    fi
    
    log_info "依赖检查完成"
}

# 安装 Node.js
install_nodejs() {
    log_step "安装 Node.js..."
    
    mkdir -p ~/apps/nodejs
    cd ~/apps/nodejs
    
    # 检测架构
    local arch=$(uname -m)
    local node_version="18.17.1"
    local pkg_name=""
    
    case $arch in
        x86_64)
            pkg_name="node-v${node_version}-linux-x64"
            ;;
        aarch64|arm64)
            pkg_name="node-v${node_version}-linux-arm64"
            ;;
        *)
            log_error "不支持的架构: $arch"
            exit 1
            ;;
    esac
    
    # 下载 Node.js
    if [ ! -d "$pkg_name" ]; then
        log_info "下载 Node.js v${node_version}..."
        
        if [ "$USE_MIRROR" = "1" ]; then
            # 使用国内镜像
            wget -q "https://npmmirror.com/mirrors/node/v${node_version}/${pkg_name}.tar.xz" --show-progress
        else
            wget -q "https://nodejs.org/dist/v${node_version}/${pkg_name}.tar.xz" --show-progress
        fi
        
        # 解压
        log_info "解压 Node.js..."
        tar -xf "${pkg_name}.tar.xz"
        rm -f "${pkg_name}.tar.xz"
    fi
    
    # 设置环境变量
    log_info "配置环境变量..."
    echo "export PATH=\"\$HOME/apps/nodejs/${pkg_name}/bin:\$PATH\"" >> ~/.bashrc
    echo "export NODE_PATH=\"\$HOME/apps/nodejs/${pkg_name}/lib/node_modules\"" >> ~/.bashrc
    
    # 立即生效
    export PATH="$HOME/apps/nodejs/${pkg_name}/bin:$PATH"
    export NODE_PATH="$HOME/apps/nodejs/${pkg_name}/lib/node_modules"
    
    # 验证安装
    if node --version &> /dev/null; then
        log_info "Node.js 版本: $(node --version)"
        log_info "npm 版本: $(npm --version)"
    else
        log_error "Node.js 安装失败"
        exit 1
    fi
}

# 安装青龙面板
install_qinglong() {
    log_step "安装青龙面板..."
    
    mkdir -p ~/apps/qinglong
    cd ~/apps/qinglong
    
    # 清理旧版本（如果存在）
    if [ -d "ql" ]; then
        log_warn "检测到旧版本，正在备份..."
        backup_dir="ql_backup_$(date +%Y%m%d_%H%M%S)"
        mv ql "$backup_dir"
        log_info "旧版本已备份到: $backup_dir"
    fi
    
    # 下载青龙面板
    log_info "下载青龙面板..."
    
    if command -v git &> /dev/null && [ "$USE_MIRROR" != "1" ]; then
        log_info "使用 Git 克隆..."
        git clone --depth=1 https://github.com/whyour/qinglong.git ql
    else
        log_info "使用压缩包下载..."
        if [ "$USE_MIRROR" = "1" ]; then
            # 使用镜像
            wget -q "https://ghproxy.com/https://github.com/whyour/qinglong/archive/refs/heads/master.tar.gz" -O qinglong.tar.gz --show-progress
        else
            wget -q "https://github.com/whyour/qinglong/archive/refs/heads/master.tar.gz" -O qinglong.tar.gz --show-progress
        fi
        
        tar -xzf qinglong.tar.gz
        mv qinglong-master ql
        rm -f qinglong.tar.gz
    fi
    
    cd ql
    
    # 配置 npm 镜像
    log_info "配置 npm 镜像源..."
    npm config set registry https://registry.npmmirror.com
    npm config set disturl https://npmmirror.com/dist
    npm config set puppeteer_download_host https://npmmirror.com/mirrors
    npm config set sass_binary_site https://npmmirror.com/mirrors/node-sass
    npm config set electron_mirror https://npmmirror.com/mirrors/electron/
    npm config set python_mirror https://npmmirror.com/mirrors/python/
    
    # 安装依赖
    log_info "安装依赖（这可能需要几分钟）..."
    
    # 先尝试正常安装
    if ! npm install --production --legacy-peer-deps; then
        log_warn "第一次安装失败，清理缓存后重试..."
        rm -rf node_modules package-lock.json
        npm cache clean --force
        
        # 再次尝试
        if ! npm install --production --legacy-peer-deps; then
            log_warn "第二次安装失败，尝试更宽松的安装方式..."
            npm install --legacy-peer-deps
        fi
    fi
    
    if [ $? -eq 0 ]; then
        log_info "青龙面板安装完成"
    else
        log_error "依赖安装失败，请检查网络连接"
        exit 1
    fi
}

# 配置青龙面板
configure_qinglong() {
    log_step "配置青龙面板..."
    
    cd ~/apps/qinglong/ql
    
    # 创建必要的目录
    mkdir -p config log scripts db jbot raw deps repo
    
    # 创建配置文件
    cat > config/extra.sh << 'EOF'
#!/bin/bash
## 青龙面板额外配置

# 时区设置
export TimeZone="Asia/Shanghai"

# 是否启用额外仓库
export EnableExtraRepo="true"

# 是否启用用户脚本
export EnableUserJs="true"

# 代理设置（如需要）
# export ProxyUrl="http://proxy.example.com:8080"
# export GithubProxyUrl="https://ghproxy.com/"
EOF
    
    chmod +x config/extra.sh
    
    # 创建 .env 文件
    cat > .env << EOF
# 青龙面板环境配置
PORT=5700
ALLOW_HTTP=true
NODE_ENV=production
CONFIG_PATH=$HOME/apps/qinglong/ql/config
LOG_PATH=$HOME/apps/qinglong/ql/log
EOF
    
    log_info "基础配置完成"
}

# 安装 PM2
install_pm2() {
    log_step "安装 PM2 进程管理器..."
    
    # 确保 Node.js 在 PATH 中
    export PATH="$HOME/apps/nodejs/node-*/bin:$PATH"
    
    if ! command -v pm2 &> /dev/null; then
        log_info "安装 PM2..."
        npm install -g pm2
        
        if [ $? -ne 0 ]; then
            log_warn "PM2 安装失败，尝试使用镜像..."
            npm config set registry https://registry.npmmirror.com
            npm install -g pm2
        fi
    fi
    
    # 设置 PM2 用户目录
    export PM2_HOME="$HOME/.pm2"
    mkdir -p "$PM2_HOME"
    
    log_info "PM2 版本: $(pm2 --version 2>/dev/null || echo '未安装')"
}

# 创建启动脚本
create_startup_scripts() {
    log_step "创建启动脚本..."
    
    # 查找可用端口
    find_available_port() {
        local base_port=${1:-5700}
        local port=$base_port
        local max_port=10000
        
        while [ $port -lt $max_port ]; do
            if ! ss -tln | grep -q ":$port "; then
                echo $port
                return 0
            fi
            port=$((port + 1))
        done
        
        # 如果没找到，使用随机高位端口
        echo $((10000 + RANDOM % 20000))
    }
    
    local ql_port=$(find_available_port 5700)
    log_info "青龙面板将使用端口: $ql_port"
    
    # 更新 .env 文件中的端口
    sed -i "s/PORT=5700/PORT=$ql_port/" ~/apps/qinglong/ql/.env
    
    # 创建简易启动脚本
    cat > ~/start_qinglong.sh << 'EOF'
#!/bin/bash
# 青龙面板启动脚本

# 设置环境
export PATH="$HOME/apps/nodejs/node-*/bin:$PATH"
cd "$HOME/apps/qinglong/ql"

# 读取端口
QL_PORT=$(grep "PORT=" .env | cut -d= -f2)
if [ -z "$QL_PORT" ]; then
    QL_PORT=5700
fi

echo "启动青龙面板，端口: $QL_PORT"
echo "访问地址: http://$(curl -s ifconfig.me 2>/dev/null || echo "localhost"):$QL_PORT"
echo "用户名: admin"
echo "密码: adminadmin"
echo ""
echo "按 Ctrl+C 停止服务"

PORT=$QL_PORT npm start
EOF
    
    chmod +x ~/start_qinglong.sh
    
    # 创建 PM2 启动脚本
    cat > ~/start_qinglong_pm2.sh << EOF
#!/bin/bash
# 青龙面板 PM2 启动脚本

# 设置环境
export PATH="\$HOME/apps/nodejs/node-*/bin:\$PATH"
export PM2_HOME="\$HOME/.pm2"

cd "\$HOME/apps/qinglong/ql"

# 读取端口
QL_PORT=\$(grep "PORT=" .env | cut -d= -f2)
if [ -z "\$QL_PORT" ]; then
    QL_PORT=5700
fi

# 创建 PM2 配置文件
cat > ecosystem.config.js << PM2EOF
module.exports = {
  apps: [{
    name: 'qinglong',
    script: 'backend/app.js',
    cwd: '\$HOME/apps/qinglong/ql',
    env: {
      PORT: \$QL_PORT,
      NODE_ENV: 'production',
      ALLOW_HTTP: 'true',
      CONFIG_PATH: '\$HOME/apps/qinglong/ql/config',
      LOG_PATH: '\$HOME/apps/qinglong/ql/log'
    },
    error_file: '\$HOME/.pm2/logs/qinglong-error.log',
    out_file: '\$HOME/.pm2/logs/qinglong-out.log',
    log_file: '\$HOME/.pm2/logs/qinglong-combined.log',
    time: true,
    autorestart: true,
    watch: false,
    max_memory_restart: '500M',
    instances: 1,
    exec_mode: 'fork'
  }]
}
PM2EOF

# 停止已存在的进程
pm2 delete qinglong 2>/dev/null || true

# 启动
echo "启动青龙面板..."
pm2 start ecosystem.config.js

# 保存配置
pm2 save

# 设置开机自启动（用户级别）
echo "设置开机自启动..."
pm2 startup -u \$USER --hp \$HOME 2>/dev/null || {
    echo "自动设置开机启动失败，请手动执行:"
    echo "pm2 startup -u \$USER --hp \$HOME"
    echo "然后执行: pm2 save"
}

echo ""
echo "========================================"
echo "青龙面板已启动！"
echo "访问地址: http://\$(curl -s ifconfig.me 2>/dev/null || echo "服务器IP"):\$QL_PORT"
echo "用户名: admin"
echo "密码: adminadmin"
echo ""
echo "管理命令:"
echo "  查看状态: pm2 status"
echo "  查看日志: pm2 logs qinglong"
echo "  重启: pm2 restart qinglong"
echo "  停止: pm2 stop qinglong"
echo ""
echo "启动脚本: ~/start_qinglong_pm2.sh"
echo "========================================"
EOF
    
    chmod +x ~/start_qinglong_pm2.sh
    
    # 创建更新脚本
    cat > ~/update_qinglong.sh << 'EOF'
#!/bin/bash
# 青龙面板更新脚本

echo "更新青龙面板..."
cd ~/apps/qinglong/ql

# 备份当前配置
backup_dir="$HOME/ql_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"
cp -r config "$backup_dir/"
cp -r scripts "$backup_dir/"
echo "配置已备份到: $backup_dir"

# 停止服务
export PATH="$HOME/apps/nodejs/node-*/bin:$PATH"
export PM2_HOME="$HOME/.pm2"
pm2 stop qinglong 2>/dev/null || true

# 更新代码
if [ -d .git ]; then
    git pull
else
    echo "非Git安装，无法自动更新"
    echo "请手动下载最新版本"
    exit 1
fi

# 更新依赖
npm install --production --legacy-peer-deps

# 重启服务
pm2 restart qinglong

echo "更新完成！"
EOF
    
    chmod +x ~/update_qinglong.sh
    
    log_info "启动脚本创建完成"
}

# 设置开机自启动
setup_autostart() {
    log_step "设置开机自启动..."
    
    # 使用 crontab 设置自启动
    local current_crontab=$(crontab -l 2>/dev/null || true)
    
    # 移除旧的青龙启动项
    local new_crontab=$(echo "$current_crontab" | grep -v "start_qinglong" | grep -v "qinglong")
    
    # 添加新的启动项（延迟60秒启动，等待网络就绪）
    local startup_line="@reboot sleep 60 && bash $HOME/start_qinglong_pm2.sh > $HOME/ql_startup.log 2>&1"
    
    # 添加到 crontab
    (echo "$new_crontab"; echo "$startup_line") | crontab -
    
    log_info "开机自启动已设置"
}

# 显示安装完成信息
show_installation_info() {
    local ql_port=$(grep "PORT=" ~/apps/qinglong/ql/.env 2>/dev/null | cut -d= -f2)
    if [ -z "$ql_port" ]; then
        ql_port=5700
    fi
    
    echo ""
    echo -e "${GREEN}✅ 安装完成！${NC}"
    echo ""
    echo "==================== 安装信息 ===================="
    echo "安装目录: ~/apps/qinglong"
    echo "Node.js: ~/apps/nodejs"
    echo "配置文件: ~/apps/qinglong/ql/config"
    echo "脚本目录: ~/apps/qinglong/ql/scripts"
    echo "日志目录: ~/apps/qinglong/ql/log"
    echo ""
    echo "==================== 启动方式 ===================="
    echo "1. 简易启动（前台运行）:"
    echo "   bash ~/start_qinglong.sh"
    echo ""
    echo "2. PM2启动（后台运行，推荐）:"
    echo "   bash ~/start_qinglong_pm2.sh"
    echo ""
    echo "3. 手动启动:"
    echo "   cd ~/apps/qinglong/ql"
    echo "   PORT=$ql_port npm start"
    echo ""
    echo "==================== 访问地址 ===================="
    echo "请使用浏览器访问:"
    echo "  http://服务器IP:$ql_port"
    echo ""
    echo "默认登录账号:"
    echo "  用户名: admin"
    echo "  密码: adminadmin"
    echo ""
    echo "==================== 管理命令 ===================="
    echo "查看状态:        pm2 status"
    echo "查看日志:        pm2 logs qinglong"
    echo "重启服务:        pm2 restart qinglong"
    echo "停止服务:        pm2 stop qinglong"
    echo "更新面板:        bash ~/update_qinglong.sh"
    echo ""
    echo "==================== 注意事项 ===================="
    echo "1. 首次登录后请立即修改密码"
    echo "2. 服务器重启后青龙会自动启动"
    echo "3. 所有数据保存在你的家目录下"
    echo "4. 无需任何管理员权限"
    echo "=================================================="
}

# 测试青龙面板
test_qinglong() {
    log_step "测试青龙面板..."
    
    # 获取端口
    local ql_port=$(grep "PORT=" ~/apps/qinglong/ql/.env 2>/dev/null | cut -d= -f2)
    if [ -z "$ql_port" ]; then
        ql_port=5700
    fi
    
    # 尝试启动并测试
    log_info "启动青龙面板进行测试..."
    
    # 使用 PM2 启动
    export PATH="$HOME/apps/nodejs/node-*/bin:$PATH"
    export PM2_HOME="$HOME/.pm2"
    
    cd ~/apps/qinglong/ql
    pm2 start ecosystem.config.js --silent
    
    # 等待启动
    log_info "等待青龙面板启动（约10秒）..."
    sleep 10
    
    # 检查进程
    if pm2 status | grep -q "qinglong"; then
        log_info "✅ 青龙面板启动成功"
        pm2 stop qinglong --silent
    else
        log_warn "⚠️  青龙面板进程未找到，但安装已完成"
    fi
}

# 主安装流程
main() {
    print_header
    
    # 检查网络
    check_network
    
    # 安装依赖
    install_deps
    
    # 安装 Node.js
    install_nodejs
    
    # 安装青龙面板
    install_qinglong
    
    # 配置青龙面板
    configure_qinglong
    
    # 安装 PM2
    install_pm2
    
    # 创建启动脚本
    create_startup_scripts
    
    # 设置开机自启动
    setup_autostart
    
    # 测试
    test_qinglong
    
    # 显示安装信息
    show_installation_info
    
    print_footer
}

# 运行主函数
main
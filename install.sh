#!/bin/bash
# 青龙面板安装脚本（修复 xz 问题）
# 直接在服务器上运行这个脚本

set -e

echo "正在修复并安装青龙面板..."

# 清理之前失败的文件
cd ~
rm -rf ~/apps/nodejs/node-v18.17.1-linux-x64.tar.xz 2>/dev/null || true

# 1. 创建目录
echo "创建目录..."
mkdir -p ~/apps/{nodejs,qinglong,bin}

# 2. 安装 Node.js（使用 tar.gz）
echo "安装 Node.js..."
cd ~/apps/nodejs

# 检测架构
ARCH=$(uname -m)
echo "系统架构: $ARCH"

if [ "$ARCH" = "x86_64" ]; then
    NODE_PKG="node-v18.17.1-linux-x64"
elif [ "$ARCH" = "aarch64" ]; then
    NODE_PKG="node-v18.17.1-linux-arm64"
else
    echo "检测到未知架构，尝试使用 x64 版本"
    NODE_PKG="node-v18.17.1-linux-x64"
fi

# 下载 tar.gz 格式
echo "下载 $NODE_PKG.tar.gz..."
wget -q "https://nodejs.org/dist/v18.17.1/${NODE_PKG}.tar.gz" --show-progress

# 解压
echo "解压 Node.js..."
tar -xzf "${NODE_PKG}.tar.gz"

# 清理
rm -f "${NODE_PKG}.tar.gz"

# 3. 设置环境变量
echo "设置环境变量..."
echo "export PATH=\"\$HOME/apps/nodejs/${NODE_PKG}/bin:\$PATH\"" >> ~/.bashrc
echo "export NODE_PATH=\"\$HOME/apps/nodejs/${NODE_PKG}/lib/node_modules\"" >> ~/.bashrc

# 立即生效
export PATH="$HOME/apps/nodejs/${NODE_PKG}/bin:$PATH"
export NODE_PATH="$HOME/apps/nodejs/${NODE_PKG}/lib/node_modules"

# 验证
echo "Node.js 版本: $(node --version)"
echo "npm 版本: $(npm --version)"

# 4. 安装青龙面板
echo "安装青龙面板..."
cd ~/apps/qinglong

# 清理旧版本
rm -rf ql qinglong-master master.tar.gz 2>/dev/null || true

# 下载青龙面板
echo "下载青龙面板..."
wget -q https://github.com/whyour/qinglong/archive/refs/heads/master.tar.gz -O qinglong.tar.gz --show-progress

# 解压
echo "解压青龙面板..."
tar -xzf qinglong.tar.gz
mv qinglong-master ql
rm -f qinglong.tar.gz

cd ql

# 5. 配置 npm 镜像
echo "配置 npm 镜像..."
npm config set registry https://registry.npmmirror.com

# 6. 安装依赖
echo "安装依赖..."
npm install --production --legacy-peer-deps

# 7. 创建必要的目录
mkdir -p config log scripts db

# 8. 创建启动脚本
echo "创建启动脚本..."
cat > ~/start_ql.sh << 'EOF'
#!/bin/bash
# 青龙面板启动脚本

# 设置环境
export PATH="$HOME/apps/nodejs/node-*/bin:$PATH"
cd "$HOME/apps/qinglong/ql"

# 查找可用端口
PORT=5700
while ss -tln | grep -q ":$PORT "; do
    PORT=$((PORT + 1))
done

echo "启动青龙面板，端口: $PORT"
echo "访问地址: http://服务器IP:$PORT"
echo "用户名: admin"
echo "密码: adminadmin"
echo ""
echo "按 Ctrl+C 停止"

PORT=$PORT npm start
EOF

chmod +x ~/start_ql.sh

# 9. 创建 PM2 启动脚本
cat > ~/start_ql_pm2.sh << 'EOF'
#!/bin/bash
# 青龙面板 PM2 启动脚本

export PATH="$HOME/apps/nodejs/node-*/bin:$PATH"
export PM2_HOME="$HOME/.pm2"

cd "$HOME/apps/qinglong/ql"

# 安装 PM2
if ! command -v pm2 &> /dev/null; then
    npm install -g pm2
fi

# 查找可用端口
PORT=5700
while ss -tln | grep -q ":$PORT "; do
    PORT=$((PORT + 1))
done

# 创建 PM2 配置文件
cat > ecosystem.config.js << PM2EOF
module.exports = {
  apps: [{
    name: 'qinglong',
    script: 'backend/app.js',
    env: {
      PORT: $PORT,
      NODE_ENV: 'production'
    }
  }]
}
PM2EOF

# 启动
pm2 start ecosystem.config.js
pm2 save

echo "青龙面板已启动！"
echo "端口: $PORT"
echo "访问: http://服务器IP:$PORT"
echo ""
echo "管理命令:"
echo "  pm2 status              # 查看状态"
echo "  pm2 logs qinglong       # 查看日志"
echo "  pm2 restart qinglong    # 重启"
EOF

chmod +x ~/start_ql_pm2.sh

# 10. 完成
echo ""
echo "========== 安装完成！ =========="
echo ""
echo "启动方式 1（前台运行）:"
echo "  bash ~/start_ql.sh"
echo ""
echo "启动方式 2（后台运行，推荐）:"
echo "  bash ~/start_ql_pm2.sh"
echo ""
echo "访问地址:"
echo "  http://服务器IP:5700"
echo "  （如果5700被占用，会自动使用其他端口）"
echo ""
echo "默认账号:"
echo "  用户名: admin"
echo "  密码: adminadmin"
echo ""
echo "Node.js 目录: ~/apps/nodejs"
echo "青龙面板目录: ~/apps/qinglong/ql"
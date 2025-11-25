# 1. 使用 slim 版本作为基础
FROM node:18-slim

WORKDIR /app

# 【核心优化 1】设置环境变量，禁止 Puppeteer/Playwright 自动下载浏览器
# 既然你手动下载了 Camoufox，就绝对不要让 npm 再下载 Chrome 了，这里能省下 500MB+
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_SKIP_DOWNLOAD=true \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=true \
    # 告诉 camoufox 的 npm 包（如果有的话）不要自动下载
    CAMOUFOX_SKIP_DOWNLOAD=true \
    NODE_ENV=production

# 2. 安装系统依赖
# 【核心优化 2】添加 --no-install-recommends
# 这可以避免安装几百 MB 的文档、图标、壁纸等无用垃圾
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    fonts-liberation \
    libasound2 libatk-bridge2.0-0 libatk1.0-0 libc6 libcairo2 libcups2 \
    libdbus-1-3 libexpat1 libfontconfig1 libgbm1 libgcc1 libglib2.0-0 \
    libgtk-3-0 libnspr4 libnss3 libpango-1.0-0 libpangocairo-1.0-0 \
    libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 \
    libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 \
    libxtst6 lsb-release wget xdg-utils xvfb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 3. 拷贝 package.json 并安装依赖
COPY package*.json ./

# 【核心优化 3】安装完依赖后，立即清理 npm 缓存
# --omit=dev 确保不安装开发依赖
RUN npm install --omit=dev && npm cache clean --force

# 4. 下载 Camoufox (保持原逻辑，这是必须的体积)
ARG CAMOUFOX_URL
# 增加 check，防止 URL 为空导致构建出一个只有空壳但层级很大的镜像
RUN if [ -z "$CAMOUFOX_URL" ]; then echo "Error: CAMOUFOX_URL is empty" && exit 1; fi && \
    curl -sSL ${CAMOUFOX_URL} -o camoufox-linux.tar.gz && \
    tar -xzf camoufox-linux.tar.gz && \
    rm camoufox-linux.tar.gz && \
    chmod +x /app/camoufox-linux/camoufox

# 5. 拷贝代码
COPY unified-server.js black-browser.js ./

# 6. 权限设置
RUN mkdir -p ./auth && chown -R node:node /app

# 切换用户
USER node

# 暴露端口
EXPOSE 7860 9998

# 环境变量
ENV CAMOUFOX_EXECUTABLE_PATH=/app/camoufox-linux/camoufox

# 启动
CMD ["node", "unified-server.js"]
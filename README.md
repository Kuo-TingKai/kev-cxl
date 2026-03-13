# CXL / 先進儲存協定模擬環境 (MacBook)

可在 **MacBook (Apple Silicon / Intel)** 上執行的 QEMU + gem5 模擬專案，用於研究 CXL 2.0/3.0、NVMe-oC、多主機共享儲存與 Cache 一致性。

---

## 專案結構

```
kev-cxl/
├── README.md                    # 本說明（Mac 環境架設步驟）
├── requirements.txt             # Python 依賴（可選）
├── scripts/
│   ├── fetch_bootable_image.sh   # 下載可開機 Alpine qcow2（避免 No bootable device）
│   ├── set_alpine_root_password.sh # 為映像設定 root 密碼（解決無法登入）
│   ├── setup_shared_mem.sh       # 建立共享記憶體檔案（多主機用）
│   ├── qemu_cxl_single.sh      # 單機 CXL Type-3 模擬
│   ├── qemu_cxl_multi_host_a.sh # 多主機 A（Port 2222）
│   └── qemu_cxl_multi_host_b.sh # 多主機 B（Port 2223）
├── gem5/
│   ├── cxl_config.py            # gem5 基礎 CXL/PCIe 風格配置
│   ├── ruby_cxl_config.py       # Ruby MESI 多核配置範本
│   └── analyze_gem5.py          # 解析 m5out/stats.txt 效能指標
├── docs/
│   └── 概念筆記.md               # 各模組重要概念說明（中文）
├── m5out/
│   └── stats.txt                # 範例統計檔（可先跑分析腳本試用）
└── docker/
    └── Dockerfile               # gem5 編譯環境（Ubuntu，供 Mac 使用）
```

---

## 一、Mac 環境準備

### 1.1 安裝必要工具

```bash
# 套件管理
brew install qemu

# 若要用 Docker 編譯 gem5（推薦）
brew install --cask orbstack   # 或 Docker Desktop
```

- **QEMU**：用於 CXL Type-3 設備模擬（x86 映像在 Apple Silicon 上會用 TCG 轉譯，較慢但可跑）。
- **OrbStack / Docker**：用於在 Linux 容器內編譯與執行 gem5，避免 macOS 編譯問題。

### 1.2 準備 Linux 映像（QEMU 用）

單機與多主機腳本皆需 **可開機的 x86_64 Linux 映像**。**僅用 `qemu-img create` 做出的空白 qcow2 無法開機**，會出現「No bootable device」。

**方式一：下載現成可開機映像（建議）**

```bash
./scripts/fetch_bootable_image.sh
export QEMU_IMAGE=$PWD/alpine-cxl.qcow2
./scripts/qemu_cxl_single.sh
```

腳本會下載約 114MB 的 Alpine Linux cloud 映像到專案目錄。

**方式二：用 ISO 安裝到空白磁碟**

若已有 Ubuntu / 其他 Linux 的安裝 ISO：

```bash
# 空白磁碟（僅做安裝目標）
qemu-img create -f qcow2 your_linux_image.qcow2 8G
export QEMU_IMAGE=$PWD/your_linux_image.qcow2
export QEMU_ISO=/path/to/ubuntu-24.04-live-server-amd64.iso
./scripts/qemu_cxl_single.sh
```

從光碟開機後，在安裝程式裡選擇該虛擬磁碟並安裝；安裝完成後下次啟動可不再設 `QEMU_ISO`。

---

## 二、QEMU 單機 CXL Type-3 模擬

### 2.1 執行

```bash
chmod +x scripts/qemu_cxl_single.sh
./scripts/qemu_cxl_single.sh
```

- 會建立 256M + 1G 的 CXL 相關記憶體後端，並掛載一個 CXL Type-3 設備。
- **Mac (ARM)**：腳本已加入 `-accel tcg`，因無法使用 KVM。
- **登入提示**：預設為 `-nographic`（僅序列埠），Alpine 的登入可能只出現在 VGA。若要看到登入畫面，請用圖形視窗：
  ```bash
  QEMU_GRAPHIC=1 ./scripts/qemu_cxl_single.sh
  ```
  會跳出 QEMU 視窗。登入方式見下方「若無法登入」。

### 2.2 登入與驗證

- **登入**：本專案下載的 generic Alpine 映像**未預設可登入帳號**（供 cloud 使用）。請先為 root 設密碼後再開機：
  ```bash
  ./scripts/set_alpine_root_password.sh
  ```
  之後以 **root** / **alpine** 登入（需 Docker；或本機安裝 `libguestfs-tools` 則不需 Docker）。序列埠（-nographic）也會出現 `localhost login:`，輸入 root 與密碼即可。
- 進入系統後可驗證 CXL：

```bash
# 查看 CXL 相關 PCI 設備
lspci -v | grep -A5 0502

# 若有安裝 ndctl：apk add ndctl
cxl list -uv

# 將 CXL 儲存轉為系統記憶體（需 kernel 支援）
daxctl reconfigure-device --mode=system-ram all
free -h   # 應看到可用 RAM 增加
```

---

## 三、QEMU 多主機共享 CXL 儲存

### 3.1 建立共享後端

```bash
chmod +x scripts/setup_shared_mem.sh
./scripts/setup_shared_mem.sh
```

會在 `/dev/shm/cxl_shared_mem` 建立 2GB 共享檔案。

### 3.2 啟動兩台虛擬機

- **終端機 1**（Host A）：

```bash
chmod +x scripts/qemu_cxl_multi_host_a.sh
./scripts/qemu_cxl_multi_host_a.sh
```

- **終端機 2**（Host B）：

```bash
chmod +x scripts/qemu_cxl_multi_host_b.sh
./scripts/qemu_cxl_multi_host_b.sh
```

兩台會透過 `share=on` 共用同一塊記憶體檔案，可觀察一致性與髒數據議題。

---

## 四、gem5 架構模擬（建議在 Docker 內執行）

### 4.1 使用 Docker 編譯 gem5（推薦在 Mac 上這樣做）

```bash
cd docker
docker build -t gem5-dev .
docker run -it --rm -v "$(pwd)/../gem5:/workspace/gem5-scripts" gem5-dev bash
# 在容器內：
# cd /gem5 && scons build/X86/gem5.opt PROTOCOL=MESI_Two_Level -j$(nproc)
```

編譯完成後，可將 `build/` 掛載出來或另建映像保存。

### 4.2 執行配置腳本（需對應你的 gem5 版本）

- `gem5/cxl_config.py`：基礎 CXL/PCIe 風格匯流排與記憶體控制器配置。
- `gem5/ruby_cxl_config.py`：多核 + Ruby MESI 範本（需以 `PROTOCOL=MESI_Two_Level` 編譯）。

在 gem5 編譯目錄下執行，例如：

```bash
./build/X86/gem5.opt ../gem5-scripts/cxl_config.py
# 或
./build/X86/gem5.opt ../gem5-scripts/ruby_cxl_config.py
```

腳本內 API 依 gem5 版本可能需微調（如 `X86TimingSimpleCPU`、`RubySystem` 等）。

### 4.3 解析 gem5 統計結果

模擬結束後會產生 `m5out/stats.txt`。使用本專案腳本擷取關鍵指標：

```bash
# 在專案根目錄執行，或指定 stats 路徑
python3 gem5/analyze_gem5.py m5out/stats.txt
```

可比較「傳統 NVMe 風格」與「CXL 風格」參數下之 CPI、L1 Miss、Coherence 訊息、平均記憶體延遲等。若 stats 檔內欄位名稱因 gem5 版本不同而改變，可編輯 `gem5/analyze_gem5.py` 中的正則表達式。

---

## 五、快速檢查清單（Mac）

| 步驟 | 指令 / 說明 |
|------|-------------|
| 1. 安裝 QEMU | `brew install qemu` |
| 2. 安裝 Docker/OrbStack | `brew install --cask orbstack` |
| 3. 建立共享記憶體（多主機） | `./scripts/setup_shared_mem.sh` |
| 4. 單機 CXL | `./scripts/qemu_cxl_single.sh`（請先改映像路徑） |
| 5. 多主機 A/B | 兩終端分別執行 `qemu_cxl_multi_host_*.sh`（請先改映像路徑） |
| 6. gem5 編譯 | 在 `docker` 映像內編譯 `build/X86/gem5.opt PROTOCOL=MESI_Two_Level` |
| 7. 分析結果 | `python3 gem5/analyze_gem5.py m5out/stats.txt` |

---

## 六、注意事項

- **Apple Silicon**：QEMU 跑 x86 使用 TCG，速度較慢；僅用於功能驗證與協定邏輯。
- **Linux 內核**：CXL 需 6.x+ 且啟用 `CONFIG_CXL_BUS`、`CONFIG_CXL_MEM`、`CONFIG_CXL_PORT`、`CONFIG_CXL_PCI`。
- **gem5**：Ruby 與 MESI 編譯選項依版本可能不同，請以官方文件為準；腳本為範本，可依需求修改參數。

---



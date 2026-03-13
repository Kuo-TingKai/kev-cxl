# 目前狀態（kev-cxl 專案）

## 已遇問題與解法

### 1. CXL LSA 裝置找不到
- **現象**：執行 `qemu_cxl_single.sh` 出現 `Device 'cxl-lsa1' not found`。
- **原因**：`-device cxl-type3,...,lsa=cxl-lsa1` 中的 `lsa` 必須對應一個以 `-object` 定義、id 為 `cxl-lsa1` 的記憶體後端，腳本原本未定義該物件。
- **解法**：新增 `-object memory-backend-file,id=cxl-lsa1,mem-path=...,size=256K`，並將揮發性記憶體（1G）與 LSA（256K）分開成兩個檔案與兩個物件。

### 2. 開機時出現「No bootable device」
- **現象**：QEMU 啟動後只看到 SeaBIOS，最後顯示 "No bootable device"。
- **原因**：使用 `qemu-img create` 建立的 qcow2 是**空白映像**，沒有安裝作業系統。
- **解法**：
  - **方式一**：執行 `./scripts/fetch_bootable_image.sh` 下載可開機的 Alpine Linux qcow2，再設定 `QEMU_IMAGE=$PWD/alpine-cxl.qcow2`。
  - **方式二**：設定 `QEMU_ISO=/path/to/install.iso`，從光碟開機後將 OS 安裝到空白 qcow2。

### 3. 硬碟被接到 CXL 橋導致無法啟動
- **現象**：使用 Alpine 映像時出現 `PCI: Only PCI/PCIe bridges can be plugged into pxb-cxl`。
- **原因**：`-drive if=virtio` 會讓 QEMU 自動選擇 PCI 插槽，有時會選到 pxb-cxl（CXL 主橋）；而 pxb-cxl 僅能接 PCI/PCIe **橋接器**，不能接 virtio-blk。
- **解法**：改為手動指定主碟接在**主 PCIe 根匯流排**（pcie.0）：使用 `-drive if=none,id=drive0` 搭配 `-device virtio-blk-pci,drive=drive0,bus=pcie.0,addr=0x6`。

---

## 待辦（Todo）

- [ ] **確認單機 CXL 開機**：在 Alpine 啟動後於 guest 內用 `cxl list -uv`、`daxctl` 驗證 CXL Type-3 設備與記憶體擴展。
- [ ] **多主機共享**：執行 `setup_shared_mem.sh` 後，在兩終端分別跑 Host A / Host B 腳本，驗證兩台 VM 共用同一 CXL 儲存。
- [ ] **gem5 編譯與執行**：在 Docker 內編譯 gem5（`PROTOCOL=MESI_Two_Level`），執行 `cxl_config.py` / `ruby_cxl_config.py`，並用 `analyze_gem5.py` 解析 `m5out/stats.txt`。
- [ ] **README 與腳本**：視實際測試結果補充或修正 README（例如 Alpine 登入方式、多主機注意事項）。

---

## 目前可執行流程（單機）

```bash
./scripts/fetch_bootable_image.sh
export QEMU_IMAGE=$PWD/alpine-cxl.qcow2
./scripts/qemu_cxl_single.sh
```

*最後更新：依本專案對話與檔案狀態整理。*

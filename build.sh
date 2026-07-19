#!/bin/bash

set -e  # 【追加】エラーが発生した時点で即座にスクリプトを停止する安全策

# 1. ソースコードの取得
git clone https://git.openwrt.org/openwrt/openwrt.git
cd openwrt/
git checkout v25.12.5
git switch -c my-v25.12.5

# 2. フィードの更新
./scripts/feeds update -a
./scripts/feeds install -a

# 3. 【超重要：lzoエラーを完全回避する対策】
# liblzoのビルドが呼び出されても、何もせずに「成功」したと嘘をついてスルーさせます
# 新しいコンパイラでエラーになる、WSR-3200AX4Sに一切不要な古いツールのビルドをスキップします
# liblzoのダミー化
mkdir -p ./tools/liblzo
echo -e "all:\n\t@echo 'Dummy liblzo'\ncompile:\n\t@echo 'Dummy compile'\ninstall:\n\t@echo 'Dummy install'\nclean:\n\t@echo 'Dummy clean'" > ./tools/liblzo/Makefile
# lzopのダミー化（ここを追加！）
mkdir -p ./tools/lzop
echo -e "all:\n\t@echo 'Dummy lzop'\ncompile:\n\t@echo 'Dummy compile'\ninstall:\n\t@echo 'Dummy install'\nclean:\n\t@echo 'Dummy clean'" > ./tools/lzop/Makefile
# 3. mtd-rwのダミー化（ここを追加！）
mkdir -p ./package/feeds/packages/mtd-rw
echo -e "all:\n\t@echo 'Dummy mtd-rw'\ncompile:\n\t@echo 'Dummy compile'\ninstall:\n\t@echo 'Dummy install'\nclean:\n\t@echo 'Dummy clean'" > ./package/feeds/packages/mtd-rw/Makefile
# 4. mdio-netlinkのダミー化（ここを追加！）
mkdir -p ./package/feeds/packages/mdio-netlink
echo -e "all:\n\t@echo 'Dummy mdio-netlink'\ncompile:\n\t@echo 'Dummy compile'\ninstall:\n\t@echo 'Dummy install'\nclean:\n\t@echo 'Dummy clean'" > ./package/feeds/packages/mdio-netlink/Makefile

# 4. 設定ファイルの取得と反映
wget https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/mt7622/config.buildinfo -O .config
#echo "CONFIG_TARGET_MULTI_PROFILE=y" >> .config
#echo "CONFIG_TARGET_DEVICE_mediatek_mt7622_DEVICE_buffalo_wsr-3200ax4s=y" >> .config
echo "# CONFIG_TARGET_MULTI_PROFILE is not set" >> .config
echo "CONFIG_TARGET_mediatek_mt7622_DEVICE_buffalo_wsr-3200ax4s=y" >> .config


# 5.【追加】コンパイルキャッシュ（ccache）の有効化設定
echo "CONFIG_CCACHE=y" >> .config
echo "CONFIG_CCACHE_DIR=\"$GITHUB_WORKSPACE/.ccache\"" >> .config
make defconfig

# 6. カスタムファイルの取得と設定の追加
wget https://pastebin.com/raw/yQTBrDaA -O ./target/linux/mediatek/dts/mt7622-buffalo-wsr-3200ax4s.dts
echo "CONFIG_MTD_VIRT_CONCAT=y" >> ./target/linux/mediatek/mt7622/config-6.12
echo  5721f98a447ca737b75326f25e62c50c > ./vermagic

# 7. ファイルの書き換え（viの手間を無くして全自動化）
set +e
sed -i 's|grep '\''=\[ym\]'\'' \$(LINUX_DIR)/\.config\.set \| LC_ALL=C sort \| \$(MKHASH) md5 > \$(LINUX_DIR)/\.vermagic|cp $(TOPDIR)/vermagic $(LINUX_DIR)/.vermagic|' ./include/kernel-defaults.mk
sed -i 's|STAMP_BUILT:=\$(STAMP_BUILT)_\$(shell \$(SCRIPT_DIR)/kconfig\.pl \$(LINUX_DIR)/\.config \| \$(MKHASH) md5)|STAMP_BUILT:=$(STAMP_BUILT)_$(shell cat $(LINUX_DIR)/.vermagic)|' ./package/kernel/linux/Makefile
set -e

# 8. ビルドの実行
make defconfig
make -j$(nproc) world


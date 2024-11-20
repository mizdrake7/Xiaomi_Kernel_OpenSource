export ARCH=arm64 && export SUBARCH=arm64 && make defconfig && mv .config arch/arm64/configs/defconfig && git add arch/arm64/configs/defconfig && git commit -m "defconfig: Regen" -s

export ARCH=arm64 && export SUBARCH=arm64 && make air_defconfig && mv .config arch/arm64/configs/air_defconfig && git add arch/arm64/configs/air_defconfig && git commit -m "air_defconfig: Regen" -s

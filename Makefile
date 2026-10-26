.PHONY: help test analyze l10n tiles serve-tiles run-android release-android appbundle

help:
	@echo "make test           ujian app (tanpa golden)"
	@echo "make analyze        flutter analyze"
	@echo "make l10n           jana semula l10n daripada .arb"
	@echo "make tiles          bina pek tile offline (Docker, ~10 min) ke tools/tiles/out"
	@echo "make serve-tiles    sajikan tools/tiles/out di :8099 (menyokong Range) untuk menguji muat turun"
	@echo "make run-android    jalankan app pada emulator dengan pek tile setempat"
	@echo "make release-android  bina APK release (arm64 + armv7), dikaburkan, simbol dipisah; tandatangan: app/android/key.properties"
	@echo "make appbundle      bina AAB untuk Play Store (WAJIB kunci release; gagal tanpanya)"

test:
	cd app && flutter test --exclude-tags golden

analyze:
	cd app && flutter analyze

l10n:
	cd app && flutter gen-l10n

tiles:
	tools/tiles/build.sh tools/tiles/data/malaysia-singapore-brunei-latest.osm.pbf tools/tiles/out

serve-tiles:
	python3 tools/tiles/serve.py tools/tiles/out 8099

# 10.0.2.2 ialah hos komputer dari emulator Android.
run-android:
	@test -s tools/tiles/out/manifest.json || { echo "Pek offline tiada. Jalankan 'make tiles' dahulu." >&2; exit 1; }
	@set -eu; \
	server_pid=; \
	if ! curl -fsS http://127.0.0.1:8099/manifest.json >/dev/null; then \
		python3 tools/tiles/serve.py tools/tiles/out 8099 & server_pid=$$!; \
		trap 'if [ -n "$$server_pid" ]; then kill "$$server_pid" 2>/dev/null || true; fi' EXIT INT TERM; \
		attempt=0; \
		until curl -fsS http://127.0.0.1:8099/manifest.json >/dev/null; do \
			attempt=$$((attempt + 1)); \
			if [ "$$attempt" -ge 50 ] || ! kill -0 "$$server_pid" 2>/dev/null; then \
				echo "Pelayan pek offline gagal dimulakan pada port 8099." >&2; exit 1; \
			fi; \
			sleep 0.1; \
		done; \
		fi; \
	cd app && flutter run --dart-define=OFFLINE_MANIFEST_URL=http://10.0.2.2:8099/manifest.json

# APK release per-ABI (lebih kecil pada peranti): simbol debug Dart dipisah ke app/build/symbols
# (simpan untuk menyahobfuskan jejak ranap). Tanpa app/android/key.properties ia ditandatangani dengan
# kunci debug dan tidak boleh diterbitkan.
release-android:
	cd app && flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols

# AAB untuk Play Store: kod Dart dikaburkan (simpan app/build/symbols untuk menyahobfuskan jejak ranap
# dan muat naik ke Play Console). FGMAP_STORE_BUILD=1 menjadikan build GAGAL jika kunci release tiada,
# supaya binari bertandatangan debug tidak pernah tersalah terbit.
appbundle:
	cd app && FGMAP_STORE_BUILD=1 flutter build appbundle --release --obfuscate --split-debug-info=build/symbols

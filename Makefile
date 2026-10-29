.PHONY: help test analyze l10n tiles serve-tiles run-android release-android appbundle check-legal

help:
	@echo "make test           ujian app (tanpa golden)"
	@echo "make analyze        flutter analyze"
	@echo "make l10n           jana semula l10n daripada .arb"
	@echo "make tiles          bina pek tile offline (Docker, ~10 min) ke tools/tiles/out"
	@echo "make serve-tiles    sajikan tools/tiles/out di :8099 (menyokong Range) untuk menguji muat turun"
	@echo "make run-android    jalankan app pada emulator dengan pek tile setempat"
	@echo "make release-android  bina APK release (arm64 + armv7), dikaburkan, simbol dipisah; tandatangan: app/android/key.properties"
	@echo "make appbundle      bina AAB untuk Play Store (WAJIB kunci release; gagal tanpanya)"
	@echo "make check-legal    gagal jika legal.release.env / LEGAL_* belum lengkap (true|owner)"

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

# Muat app/android/legal.release.env, kemudian override dengan argumen make jika diberi.
define load-legal
	if [ -f app/android/legal.release.env ]; then set -a; . ./app/android/legal.release.env; set +a; fi; \
	if [ -n "$(LEGAL_EMAIL)" ]; then LEGAL_EMAIL="$(LEGAL_EMAIL)"; fi; \
	if [ -n "$(LEGAL_ADDRESS)" ]; then LEGAL_ADDRESS="$(LEGAL_ADDRESS)"; fi; \
	if [ -n "$(LEGAL_REG_NO)" ]; then LEGAL_REG_NO="$(LEGAL_REG_NO)"; fi; \
	if [ -n "$(LEGAL_REVIEWED)" ]; then LEGAL_REVIEWED="$(LEGAL_REVIEWED)"; fi
endef

# AAB untuk Play Store: kod Dart dikaburkan (simpan app/build/symbols untuk menyahobfuskan jejak ranap
# dan muat naik ke Play Console). FGMAP_STORE_BUILD=1 menjadikan build GAGAL jika kunci release tiada,
# supaya binari bertandatangan debug tidak pernah tersalah terbit.
# LEGAL_REVIEWED=true → dart true (tiada notis draf). owner/lain → dart false (notis draf kekal).
appbundle: check-legal
	@set -eu; \
	$(load-legal); \
	dart_reviewed=false; \
	if [ "$$LEGAL_REVIEWED" = "true" ]; then dart_reviewed=true; fi; \
	cd app && FGMAP_STORE_BUILD=1 flutter build appbundle --release --obfuscate --split-debug-info=build/symbols \
		--dart-define=LEGAL_REVIEWED=$$dart_reviewed \
		--dart-define=LEGAL_EMAIL=$$LEGAL_EMAIL --dart-define=LEGAL_ADDRESS="$$LEGAL_ADDRESS" \
		--dart-define=LEGAL_REG_NO="$$LEGAL_REG_NO"

# Pintu pelancaran dokumen undang-undang. Isi app/android/legal.release.env atau:
#   make appbundle LEGAL_EMAIL=... LEGAL_ADDRESS="..." LEGAL_REG_NO=... LEGAL_REVIEWED=true|owner
# LEGAL_REVIEWED=true HANYA selepas peguam menyemak; owner = pemilik akui draf untuk muat naik ujian.
check-legal:
	@set -eu; \
	$(load-legal); \
	missing=""; \
	[ -n "$${LEGAL_EMAIL:-}" ] || missing="$$missing LEGAL_EMAIL"; \
	[ -n "$${LEGAL_ADDRESS:-}" ] || missing="$$missing LEGAL_ADDRESS"; \
	[ -n "$${LEGAL_REG_NO:-}" ] || missing="$$missing LEGAL_REG_NO"; \
	case "$${LEGAL_REVIEWED:-}" in true|owner) ;; \
	  *) missing="$$missing LEGAL_REVIEWED=true|owner" ;; \
	esac; \
	if [ -n "$$missing" ]; then echo "Dokumen undang-undang belum siap. Belum diisi:$$missing" >&2; exit 1; fi

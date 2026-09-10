# Atalhos p/ rodar o projeto localmente.  `make` ou `make help` lista os alvos.
FLUTTER ?= $(HOME)/development/flutter/bin/flutter

.DEFAULT_GOAL := help
.PHONY: help setup demo demo-device run apk web test analyze doctor clean

help: ## lista os alvos
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

setup: ## flutter pub get
	$(FLUTTER) pub get

demo: ## roda a DEMO (mock M4) no Chrome — nao precisa de backend
	$(FLUTTER) run -d chrome -t lib/main_demo.dart

demo-device: ## roda a DEMO no device/emulador conectado
	$(FLUTTER) run -t lib/main_demo.dart

run: config/local.json ## roda o app REAL no device (le config/local.json)
	$(FLUTTER) run -t lib/main.dart --dart-define-from-file=config/local.json

apk: config/local.json ## gera build/app/outputs/flutter-apk/app-debug.apk
	$(FLUTTER) build apk --debug --dart-define-from-file=config/local.json

ios: config/local.json ## build iOS sem assinatura (precisa Xcode completo + CocoaPods)
	cd ios && pod install
	$(FLUTTER) build ios --debug --no-codesign --dart-define-from-file=config/local.json

web: ## build web da demo -> build/web
	$(FLUTTER) build web -t lib/main_demo.dart

test: ## flutter test
	$(FLUTTER) test

analyze: ## flutter analyze
	$(FLUTTER) analyze

doctor: ## flutter doctor
	$(FLUTTER) doctor

clean: ## flutter clean (libera espaco em disco)
	$(FLUTTER) clean

config/local.json:
	@cp config/local.example.json config/local.json
	@echo ">>> criado config/local.json a partir do exemplo — edite com sua URL/DID"

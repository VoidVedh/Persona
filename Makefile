.PHONY: all doctor build test app run restore verify-clean probe

all: build

doctor:
	@bash scripts/doctor.sh

build:
	@swift build

test:
	@swift run persona-selftest

app:
	@if [ -f scripts/build_app.sh ]; then bash scripts/build_app.sh; else echo "app packaging script not yet created"; fi

run:
	@if [ -d "build/Persona Mode.app" ]; then open "build/Persona Mode.app"; else echo "app not yet built; run make app first"; fi

restore:
	@if [ -f scripts/restore_macos.sh ]; then bash scripts/restore_macos.sh; else echo "restore script not yet created"; fi

verify-clean:
	@if [ -f scripts/verify_clean_state.sh ]; then bash scripts/verify_clean_state.sh; else echo "verify-clean not yet created"; fi

probe:
	@swift run PersonaMode --probe $(P)

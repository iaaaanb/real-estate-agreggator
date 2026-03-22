.PHONY: help up down db-up api frontend setup db-shell redis-shell lint test ingest

help: ## Mostrar esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

# ─── Infraestructura ────────────────────────────────────────
up: ## Levantar PostgreSQL + Redis
	docker compose up -d

down: ## Bajar todo
	docker compose down

db-up: ## Levantar solo la BD
	docker compose up -d db

db-shell: ## Abrir psql
	docker compose exec db psql -U propiedades -d propiedades

redis-shell: ## Abrir redis-cli
	docker compose exec redis redis-cli

db-reset: ## Borrar y recrear la BD (DESTRUCTIVO)
	docker compose down -v
	docker compose up -d db
	@echo "Esperando que PostgreSQL arranque..."
	@sleep 3
	@echo "BD recreada. La migración SQL se ejecutó automáticamente."

# ─── Backend ────────────────────────────────────────────────
setup-backend: ## Instalar dependencias Python con uv
	cd backend && uv sync --all-extras

api: ## Correr FastAPI en modo desarrollo
	cd backend && uv run uvicorn app.main:app --reload --port 8000

lint: ## Lint del backend
	cd backend && uv run ruff check . --fix

test: ## Tests del backend
	cd backend && uv run pytest -v

# ─── Frontend ───────────────────────────────────────────────
setup-frontend: ## Instalar dependencias Node
	cd frontend && npm install

frontend: ## Correr Next.js en modo desarrollo
	cd frontend && npm run dev

# ─── Setup inicial ──────────────────────────────────────────
setup: setup-backend setup-frontend ## Setup completo del proyecto
	cp -n .env.example .env 2>/dev/null || true
	@echo ""
	@echo "✓ Setup completo. Pasos siguientes:"
	@echo "  1. Edita .env con tus credenciales de MercadoLibre"
	@echo "  2. make up          (levantar BD + Redis)"
	@echo "  3. make api         (en una terminal)"
	@echo "  4. make frontend    (en otra terminal)"
	@echo "  5. Abrir http://localhost:3000"

# ─── Ingesta ────────────────────────────────────────────────
ingest: ## Correr ingesta inicial de MercadoLibre
	cd backend && uv run python -m ingestion.run

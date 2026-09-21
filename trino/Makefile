SHELL := /bin/sh
COMPOSE := docker compose

.PHONY: up down ddl seed etl reports all

up:
	$(COMPOSE) up -d
	@printf '%s\n' 'Waiting for Trino to become ready...'
	@until curl -fsS http://localhost:8080/v1/info | grep -q '"starting":false'; do sleep 2; done

down:
	$(COMPOSE) down

ddl:
	@set -e; for file in sql/ddl/*.sql; do \
		$(COMPOSE) exec -T trino trino -f "/workspace/$$file"; \
	done

seed:
	@set -e; for file in sql/seed/*.sql; do \
		$(COMPOSE) exec -T trino trino -f "/workspace/$$file"; \
	done

etl:
	@set -e; for file in sql/etl/*.sql; do \
		$(COMPOSE) exec -T trino trino -f "/workspace/$$file"; \
	done

reports:
	@set -e; for file in sql/reports/*.sql; do \
		printf '\n--- %s ---\n' "$$file"; \
		$(COMPOSE) exec -T trino trino -f "/workspace/$$file"; \
	done

all: up ddl seed etl reports

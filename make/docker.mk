# ═══════════════════════════════════════════════════════════════
# 󰡨 DOCKER - Privileged Arch systemd sandbox for shared_dir
# ═══════════════════════════════════════════════════════════════

DOCKER_IMAGE ?= shared_dir:local
DOCKERFILE ?= Dockerfile
DOCKER_TEST_IMAGES := shared_dir:local
DOCKER_CONTAINER ?= shared_dir-sandbox

# systemd needs a writable cgroup hierarchy and enough privileges for unit
# startup inside the sandbox. The container is ephemeral and is not mounted
# onto the host home directory.
#
# PID 1 is systemd (not the installer). docker-run starts the container
# detached, waits until systemd is up, runs shared_dir interactively, then
# drops into a root shell so the result can be inspected. Leaving the shell
# removes the container.
#
# Interactive docker exec / shell teardown often returns 130 (SIGINT). That is
# a normal end of the trial, not a Make failure — docker-run always cleans up
# and exits 0 after the inspection shell.
DOCKER_RUN_FLAGS := --privileged --cgroupns=host --volume /sys/fs/cgroup:/sys/fs/cgroup:rw
DOCKER_READY_TIMEOUT ?= 30

.PHONY: help-docker docker-build docker-run docker-clean docker-clean-all

help-docker: ## Show Docker targets
	@printf "\n"
	@printf "$(CYAN)Docker targets$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  make docker-build           Build the local Arch systemd image\n"
	@printf "  make docker-run             Start the sandbox and launch shared_dir\n"
	@printf "  make docker-clean           Remove the local image\n"
	@printf "  make docker-clean-all       Remove all local shared_dir test images\n"
	@printf "\n"

docker-build: ## Build the local Docker image
	@command -v docker > /dev/null || { printf "$(RED)Docker is not installed$(NC)\n"; exit 1; }
	@docker build --file "$(DOCKERFILE)" --tag "$(DOCKER_IMAGE)" .

docker-run: ## Run shared_dir automatically in a privileged systemd sandbox
	@command -v docker > /dev/null || { printf "$(RED)Docker is not installed$(NC)\n"; exit 1; }
	@$(MAKE) --no-print-directory docker-build
	@if docker container inspect "$(DOCKER_CONTAINER)" > /dev/null 2>&1; then \
		printf "$(YELLOW)Removing leftover sandbox container: $(DOCKER_CONTAINER)$(NC)\n"; \
		docker rm -f "$(DOCKER_CONTAINER)" > /dev/null; \
	fi
	@printf "\n"
	@printf "$(CYAN)󰡨  shared_dir · ephemeral Docker trial$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  $(DIM)Isolated throwaway container — your host stays untouched.$(NC)\n"
	@printf "  $(DIM)Nothing created inside survives when this session ends.$(NC)\n"
	@printf "\n"
	@printf "  $(BLUE)▸$(NC) Booting systemd sandbox...\n"
	@docker run -d --name "$(DOCKER_CONTAINER)" $(DOCKER_RUN_FLAGS) "$(DOCKER_IMAGE)" > /dev/null
	@ready=0; \
	i=0; \
	while [ "$$i" -lt "$(DOCKER_READY_TIMEOUT)" ]; do \
		if ! docker container inspect "$(DOCKER_CONTAINER)" > /dev/null 2>&1; then \
			printf "$(RED)Sandbox container exited before systemd became ready$(NC)\n"; \
			docker logs "$(DOCKER_CONTAINER)" 2>/dev/null || true; \
			docker rm -f "$(DOCKER_CONTAINER)" > /dev/null 2>&1 || true; \
			exit 1; \
		fi; \
		state=$$(docker exec "$(DOCKER_CONTAINER)" systemctl is-system-running 2>/dev/null || true); \
		case $$state in \
			running|degraded|starting) \
				if [ "$$state" = running ] || [ "$$state" = degraded ]; then \
					ready=1; \
					break; \
				fi; \
				;; \
		esac; \
		i=$$((i + 1)); \
		sleep 1; \
	done; \
	if [ "$$ready" -ne 1 ]; then \
		printf "$(RED)Timed out waiting for systemd inside the sandbox$(NC)\n"; \
		docker logs "$(DOCKER_CONTAINER)" 2>/dev/null || true; \
		docker rm -f "$(DOCKER_CONTAINER)" > /dev/null 2>&1 || true; \
		exit 1; \
	fi
	@printf "  $(GREEN)✓$(NC) Sandbox is live\n"
	@printf "  $(BLUE)▸$(NC) Interactive terminal open inside the container: running $(CYAN)shared_dir$(NC) for testing.\n"
	@printf "\n"
	@printf "$(YELLOW)  All installer changes stay in this throwaway environment.$(NC)\n"
	@printf "$(YELLOW)  They never reach your local machine.$(NC)\n"
	@printf "\n"
	@trap 'docker rm -f "$(DOCKER_CONTAINER)" > /dev/null 2>&1 || true' EXIT; \
		docker exec -it "$(DOCKER_CONTAINER)" /usr/local/bin/shared_dir || true; \
		printf "\n"; \
		printf "$(CYAN)󰡨  shared_dir finished inside the sandbox$(NC)\n"; \
		printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"; \
		printf "  $(DIM)Root shell for inspection (systemctl, getfacl, ls).$(NC)\n"; \
		printf "  $(DIM)Type exit — the container is destroyed and the host is unchanged.$(NC)\n"; \
		printf "\n"; \
		docker exec -it "$(DOCKER_CONTAINER)" /bin/bash || true; \
		docker rm -f "$(DOCKER_CONTAINER)" > /dev/null 2>&1 || true; \
		trap - EXIT; \
		printf "\n"; \
		printf "  $(GREEN)✓$(NC) Ephemeral sandbox removed. Host unchanged.\n"; \
		printf "\n"; \
		exit 0

docker-clean: ## Remove the local Docker image
	@command -v docker > /dev/null || { printf "$(RED)Docker is not installed$(NC)\n"; exit 1; }
	@case " $(DOCKER_TEST_IMAGES) " in \
		*" $(DOCKER_IMAGE) "*) ;; \
		*) printf "$(RED)Refusing to remove unmanaged Docker image: $(DOCKER_IMAGE)$(NC)\n"; exit 1;; \
	esac
	@if docker container inspect "$(DOCKER_CONTAINER)" > /dev/null 2>&1; then \
		docker rm -f "$(DOCKER_CONTAINER)" > /dev/null; \
	fi
	@if docker image inspect "$(DOCKER_IMAGE)" > /dev/null 2>&1; then \
		docker image rm "$(DOCKER_IMAGE)"; \
	else \
		printf "$(GREEN)No local Docker image to remove$(NC)\n"; \
	fi

docker-clean-all: ## Remove all local Docker test images
	@command -v docker > /dev/null || { printf "$(RED)Docker is not installed$(NC)\n"; exit 1; }
	@if docker container inspect "$(DOCKER_CONTAINER)" > /dev/null 2>&1; then \
		docker rm -f "$(DOCKER_CONTAINER)" > /dev/null; \
	fi
	@for image in $(DOCKER_TEST_IMAGES); do \
		if docker image inspect "$$image" > /dev/null 2>&1; then \
			docker image rm "$$image"; \
		else \
			printf "$(GREEN)No local Docker image to remove: $$image$(NC)\n"; \
		fi; \
	done

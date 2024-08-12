# Makefile

# Default target: Show help when no other command is specified
.DEFAULT_GOAL := help

# Color mapping: Regular and bold ANSI color codes
COLORS = black=30 red=31 green=32 yellow=33 blue=34 magenta=35 cyan=36 white=37 \
         black_bold=90 red_bold=91 green_bold=92 yellow_bold=93 blue_bold=94 magenta_bold=95 cyan_bold=96 white_bold=97

# Help target: Print a list of all targets with descriptions, categorized by groups
help:
	@echo "Available commands:"
	@awk -F':|##' '
		BEGIN { \
			split("$(COLORS)", color_map, " "); \
			for (i in color_map) { \
				split(color_map[i], kv, "="); \
				color_codes[kv[1]] = kv[2]; \
			} \
		} \
		/^##[a-zA-Z_]+ / { \
			color_name = gensub(/^##([a-zA-Z_]+) .*/, "\\1", "g", $$1); \
			color_code = color_codes[color_name]; \
			if (!color_code) color_code = 37; \
			color = sprintf("\033[1;%dm", color_code); \
			printf "\n%s%s%s\n", color, gensub(/^##[a-zA-Z_]+ /, "", "g", $$1), "\033[0m"; \
		} \
		/^[a-zA-Z_-]+:.*##/ { \
			target_color = gensub(/^##([a-zA-Z_]+) .*/, "\\1", "g", $$2); \
			color_code = color_codes[target_color]; \
			if (!color_code) color_code = 37; \
			color = sprintf("\033[1;%dm", color_code); \
			printf "  %s%-20s %s%s\n", color, $$1, $$3, "\033[0m"; \
		}' $(MAKEFILE_LIST)

##black General
install: ##black Install dependencies
	@echo "Installing dependencies..."

update: ##black Update project dependencies
	@echo "Updating dependencies..."

##red Build and Clean
build: ##red Build the project
	@echo "Building the project..."

clean: ##red Clean the project
	@echo "Cleaning the project..."

##green Tests and Quality
test: ##green Run the test suite
	@echo "Running tests..."

lint: ##green Run the linter
	@echo "Linting the code..."

##yellow_bold Documentation
docs: ##yellow_bold Generate project documentation
	@echo "Generating documentation..."

##blue_bold Deployment
deploy: ##blue_bold Deploy the application
	@echo "Deploying the application..."

##magenta_bold Advanced Usage
rollback: ##magenta_bold Rollback to previous version
	@echo "Rolling back..."

.PHONY: help install update build clean test lint docs deploy rollback


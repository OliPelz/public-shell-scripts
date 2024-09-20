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

.PHONY: help install
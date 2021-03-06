SHELL := /bin/bash

MPLBACKEND?=Agg
export MPLBACKEND

MODULES=starfish examples sptx_format

define print_help
    @printf "    %-24s   $(2)\n" $(1)
endef

define create_venv
    if [[ "$(TRAVIS)" = "" ]]; then \
        python -m venv $(1); \
    else \
        virtualenv -p $$(which python) $(1); \
    fi
endef


all:	fast

### UNIT #####################################################
#
fast:	lint mypy test

lint:   lint-non-init lint-init

lint-non-init:
	flake8 --ignore 'E252, E301, E302, E305, E401, W503, W605, E731, F811' --exclude='*__init__.py' $(MODULES)

lint-init:
	flake8 --ignore 'E252, E301, E302, E305, E401, F401, W503, W605, E731, F811' --filename='*__init__.py' $(MODULES)

test:
	pytest -v -n 8 --cov starfish --cov sptx_format

mypy:
	mypy --ignore-missing-imports $(MODULES)

help-unit:
	$(call print_help, all, alias for fast)

.PHONY: all fast lint lint-non-init lint-init test mypy help-unit
#
##############################################################

### DOCS #####################################################
#
docs-%:
	make -C docs $*

help-docs:
	$(call print_help, docs-TASK, alias for 'make TASK' in the docs subdirectory)

.PHONY: help-docs
#
##############################################################

### REQUIREMENTS #############################################
#
check_requirements:
	if [[ $$(git status --porcelain REQUIREMENTS*) ]]; then \
	    echo "Modifications found in REQUIREMENTS files"; exit 2; \
	fi

refresh_all_requirements:
	@echo -n '' >| REQUIREMENTS.txt
	@if [ $$(uname -s) == "Darwin" ]; then sleep 1; fi  # this is require because Darwin HFS+ only has second-resolution for timestamps.
	@touch REQUIREMENTS.txt.in
	@$(MAKE) REQUIREMENTS.txt

REQUIREMENTS.txt : %.txt : %.txt.in
	[ ! -e .requirements-env ] || exit 1
	$(call create_venv, .$<-env)
	.$<-env/bin/pip install -r $@
	.$<-env/bin/pip install -r $<
	echo "# You should not edit this file directly.  Instead, you should edit one of the following files ($^) and run make $@" >| $@
	.$<-env/bin/pip freeze >> $@
	rm -rf .$<-env

help-requirements:
	$(call print_help, refresh_all_requirements, regenerate requirements files)
	$(call print_help, check_requirements, fail if requirements files have been modified)

.PHONY: refresh_all_requirements
#
##############################################################

### INTEGRATION ##############################################
#
include notebooks/subdir.mk

slow: fast run_notebooks docker

docker:
	docker build -t spacetx/starfish .
	docker run -ti --rm spacetx/starfish build --fov-count 1 --hybridization-dimensions '{"z": 1}' /tmp/

help-integration:
	$(call print_help, slow, alias for 'fast run_notebooks docker')
	$(call print_help, run_notebooks, run all files matching 'notebooks/py/*.py')
	$(call print_help, docker, build docker and run a simple container)

.PHONY: slow docker
#
##############################################################

### INSTALL ##################################################
#
install-src:
	pip install --force-reinstall --upgrade -r REQUIREMENTS.txt
	pip install -e .
	pip freeze

install-pypi:
	pip install -r REQUIREMENTS.txt starfish

help-install:
	$(call print_help, install-src, pip install the current directory)
	$(call print_help, install-pypi, pip install starfish from pypi)
	$(call print_help, install-travis, chooses between src and pypi based on TRAVIS_EVENT_TYPE)

.PHONY: install-src install-pypi
#
###############################################################

help: help-main help-parts
help-main:
	@echo Main starfish make targets:
	@echo =======================================================================================
	$(call print_help, help, print this text)
help-parts: help-unit help-docs help-requirements help-integration help-install
	@echo =======================================================================================
	@echo Default: all

.PHONY: help help-unit help-requirements help-integration help-install

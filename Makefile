# Makefile utilities for running tests and publishing the package

PLUGIN_PACKAGES:=stor_dx/ stor_swift/ stor_s3/
PACKAGE_NAMES:=$(PLUGIN_PACKAGES) stor/
TEST_OUTPUT?=nosetests.xml
PIP_INDEX_URL=https://pypi.python.org/simple/
PYTHON?=$(shell which python)

ifdef TOX_ENV
	TOX_ENV_FLAG := -e $(TOX_ENV)
else
	TOX_ENV_FLAG :=
endif

.PHONY: default
default:
	cd stor; python setup.py check build; cd ..

VENV_DIR?=.venv
VENV_ACTIVATE=$(VENV_DIR)/bin/activate
WITH_VENV=. $(VENV_ACTIVATE);
WITH_PBR=$(WITH_VENV) PBR_REQUIREMENTS_FILES=requirements-pbr.txt

.PHONY: venv
venv: $(VENV_ACTIVATE)

$(VENV_ACTIVATE): stor*/requirements*.txt
	test -f $@ || virtualenv --python=$(PYTHON) $(VENV_DIR)
	$(WITH_VENV) echo "Within venv, running $$(python --version)"
	$(WITH_VENV) pip install -r requirements-setup.txt --index-url=${PIP_INDEX_URL}
	$(WITH_VENV) ./run_all.sh 'pip install -r requirements-test.txt --index-url=${PIP_INDEX_URL}' $(PACKAGE_NAMES)
	$(WITH_VENV) ./run_all.sh 'pip install --no-deps -e . --index-url=${PIP_INDEX_URL}' $(PACKAGE_NAMES)
	$(WITH_VENV) pip install -r requirements-dev.txt  --index-url=${PIP_INDEX_URL}
	$(WITH_VENV) pip install -r requirements-docs.txt --index-url=${PIP_INDEX_URL}
	touch $@

develop: venv
	$(WITH_VENV) ./run_all.sh 'python setup.py develop' $(PACKAGE_NAMES)

.PHONY: docs
docs: venv clean-docs
	$(WITH_VENV) cd docs && make html

.PHONY: setup
setup: ##[setup] Run an arbitrary setup.py command
setup: venv
ifdef ARGS
	$(WITH_PBR) ./run_all.sh 'python setup.py ${ARGS}' $(PACKAGE_NAMES)
else
	@echo "Won't run 'python setup.py ${ARGS}' without ARGS set."
endif

.PHONY: clean
clean:
	./run_all.sh '$(PYTHON) setup.py clean' $(PACKAGE_NAMES)
	./run_all.sh 'rm -rf *.egg*/' $(PACKAGE_NAMES) .
	./run_all.sh 'rm -rf .*egg*/' $(PACKAGE_NAMES) .
	./run_all.sh 'rm -rf dist/' $(PACKAGE_NAMES)
	./run_all.sh 'rm -rf build/' $(PACKAGE_NAMES)
	./run_all.sh 'rm -rf __pycache__/' $(PACKAGE_NAMES) .
	./run_all.sh 'rm -rf .*cache/' $(PACKAGE_NAMES) .
	rm -f MANIFEST
	rm -f $(TEST_OUTPUT)
	./run_all.sh 'find . -type f -name '*.pyc' -delete' $(PACKAGE_NAMES) .
	rm -rf nosetests* "${TEST_OUTPUT}" coverage .coverage


.PHONY: clean-docs
clean-docs:
	$(WITH_VENV) cd docs && make clean


.PHONY: teardown
teardown:
	rm -rf $(VENV_DIR)

.PHONY: lint
lint: venv
	$(WITH_VENV) ./run_all.sh 'flake8 .' $(PACKAGE_NAMES)

.PHONY: unit-test
unit-test: venv
	$(WITH_VENV) \
	coverage erase; \
	tox -v $(TOX_ENV_FLAG); \
	status=$$?; \
	exit $$status;

.PHONY: test
test: venv docs unit-test
ifndef SWIFT_TEST_USERNAME
	echo "Please set SWIFT_TEST_USERNAME and SWIFT_TEST_PASSWORD to run swift integration tests" 1>&2
endif
ifndef AWS_TEST_ACCESS_KEY_ID
	echo "Please set AWS_TEST_ACCESS_KEY_ID and AWS_TEST_SECRET_ACCESS_KEY to run s3 integration tests" 1>&2
endif
ifndef DX_AUTH_TOKEN
	echo "Please set DX_AUTH_TOKEN to run DX integration tests" 1>&2
endif

# setting this up so that we can use virtualenv, coverage, etc
.PHONY: travis-test
travis-test: venv
	$(WITH_VENV) \
	./run_all.sh 'coverage erase' $(PACKAGE_NAMES) .; \
	./run_all.sh 'coverage run setup.py test' $(PACKAGE_NAMES); \
	coverage combine stor*/.coverage; \
	status=$$?; \
	coverage report && exit $$status;

# Distribution

VERSION=$(shell $(WITH_PBR) cd stor; python setup.py --version | sed 's/\([0-9]*\.[0-9]*\.[0-9]*\).*$$/\1/'; cd ..)

.PHONY: tag
tag: ##[distribution] Tag the release.
tag: venv
	echo "Tagging version as ${VERSION}"
	git tag -a ${VERSION} -m "Version ${VERSION}"
	# We won't push changes or tags here allowing the pipeline to do that, so we don't accidentally do that locally.

.PHONY: dist
dist: venv fullname
	# dynamically set the version in each requirements file to be the version of the package being installed
	$(WITH_VENV) \
	./run_all.sh 'cp requirements.txt requirements.txt.old' $(PLUGIN_PACKAGES); \
	for plugin in $(PLUGIN_PACKAGES); do \
		awk -v p=stor -v v=$(VERSION) '$$0 ~ p {gsub("$$","=="v,$$0)}1' < $$plugin/requirements.txt > $$plugin/requirements.txt.tmp ; \
		mv $$plugin/requirements.txt.tmp $$plugin/requirements.txt; \
	done; \
	./run_all.sh 'python setup.py sdist' $(PLUGIN_PACKAGES); \
	./run_all.sh 'mv requirements.txt.old requirements.txt' $(PLUGIN_PACKAGES); \
	cp stor/requirements.txt stor/requirements.txt.old; \
	for plugin in $(subst /,,$(PLUGIN_PACKAGES)); do \
		awk -v p=$$plugin -v v=$(VERSION) '$$0 ~ p {gsub("$$","=="v,$$0)}1' < stor/requirements.txt > stor/requirements.txt.tmp ; \
		mv stor/requirements.txt.tmp stor/requirements.txt; \
	done; \
	./run_all.sh 'python setup.py sdist' stor/ ; \
	mv stor/requirements.txt.old stor/requirements.txt; \

.PHONY: publish-docs
publish-docs:
	./publish_docs.sh

.PHONY: sdist
sdist: dist
	@echo "runs dist"

.PHONY: version
version: venv
	@echo ${VERSION}

.PHONY: fullname
fullname:
	./run_all.sh '$(PYTHON) setup.py --fullname' $(PACKAGE_NAMES)

#!/usr/bin/env bash

ctags --exclude='.tox' --exclude='venv-*/*' --exclude='venv/*' --exclude='*.min.*' --exclude='*-min.*' --exclude='*/CACHE/*' --exclude='*/ckeditor/*' --exclude='*/node_modules/*' --exclude='node_modules/*' --exclude='*/coverage/*' --exclude='media/*' --exclude='collected_static/*' --exclude='static/*' --exclude='*.pyc' -R "$@"

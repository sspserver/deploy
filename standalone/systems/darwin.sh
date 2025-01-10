#!/usr/bin/env bash

# 1. Install docker if not installed
if ! command -v docker &> /dev/null
then
    echo "Error: docker could not be found"
    echo "Installing docker first..."
    exit 1
fi

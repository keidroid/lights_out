#!/bin/bash
find . -name "*.dart" | xargs cat | wc -c

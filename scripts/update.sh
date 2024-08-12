#!/bin/sh

cd "$(dirname "$0")" || exit
cd ..

just update -y
just bundle

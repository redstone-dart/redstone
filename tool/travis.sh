#!/usr/bin/env bash
set -e

pub global activate tuneup
pub global run tuneup check

dart --checked test/server_tests.dart

#!/usr/bin/env bash
pwd
ls -larth
ls -Rla coverage/
bundle
rake coverage:report
ls -la coverage/coverage.xml
cat coverage/coverage.xml
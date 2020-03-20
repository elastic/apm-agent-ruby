#!/usr/bin/env bash
pwd
ls -larth
ls -R coverage/
bundle
rake coverage:report

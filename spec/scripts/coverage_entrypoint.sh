#!/usr/bin/env bash
pwd
ls -larth
ls -Ra coverage/
bundle
rake coverage:report

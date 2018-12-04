#!/bin/bash

ls | grep tgz | xargs -I {} docker load -i ./{}
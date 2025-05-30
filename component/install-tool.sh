#!/bin/sh
set -x

name=''

if [ $# -eq 1 ]; then
    name="${1}"
else
    echo "请传入一个参数。" >&2
	exit 1
fi

if ! tar -xzf /tmp/file.tar.gz -C /opt/; then
    echo "Error: Failed to extract the name archive. Exiting with status 1." >&2
    exit 1
fi

EXTRACTED_DIR=$(tar -tzf /tmp/file.tar.gz | head -n 1 | cut -f1 -d"/")

if ! mv "/opt/${EXTRACTED_DIR}" "/opt/${name}"; then
    echo "Error: Failed to rename the extracted directory. Exiting with status 1." >&2
    exit 1
fi

if ! rm -f /tmp/file.tar.gz; then
    echo "Error: Failed to remove the downloaded archive. Exiting with status 1." >&2
    exit 1
fi
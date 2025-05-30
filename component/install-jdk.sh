#!/bin/sh
set -x
# Check if at least one argument was passed to the script
# If one argument was passed and JAVA_VERSION is set, assign the argument to OS
# If two arguments were passed, assign them to JAVA_VERSION and OS respectively
# If three arguments were passed, assign them to JAVA_VERSION, OS and ARCHS respectively
# If not, check if JAVA_VERSION and OS are already set. If they're not set, exit the script with an error message
if [ $# -eq 1 ] && [ -n "${JAVA_VERSION}" ]; then
    OS="${1}"
elif [ $# -eq 2 ]; then
    JAVA_VERSION="${1}"
    OS="${2}"
elif [ $# -eq 3 ]; then
    JAVA_VERSION="${1}"
    OS="${2}"
    ARCHS=$3
elif [ -z "${JAVA_VERSION}" ] && [ -z "${OS}" ]; then
    echo "Error: No Java version and OS specified. Please set the JAVA_VERSION and OS environment variables or pass them as arguments." >&2
    exit 1
elif [ -z "${JAVA_VERSION}" ]; then
    echo "Error: No Java version specified. Please set the JAVA_VERSION environment variable or pass it as an argument." >&2
    exit 1
elif [ -z "${OS}" ]; then
    OS="${1}"
    if [ -z "${OS}" ]; then
        echo "Error: No OS specified. Please set the OS environment variable or pass it as an argument." >&2
        exit 1
    fi
fi

# Check if ARCHS is set. If it's not set, assign the current architecture to it
if [ -z "${ARCHS}" ]; then
    ARCHS=$(uname -m | sed -e 's/x86_64/x64/' -e 's/armv7l/arm/')
else
    # Convert ARCHS to an array
    OLD_IFS="${IFS}"
    IFS=','
    set -- "${ARCHS}"
    ARCHS=""
    for arch in "$@"; do
        ARCHS="${ARCHS} ${arch}"
    done
    IFS="${OLD_IFS}"
fi

# Check if jq and curl are installed
# If they are not installed, exit the script with an error message
if ! command -v curl >/dev/null 2>&1; then
    echo "curl are required but not installed. Exiting with status 1." >&2
    exit 1
fi

VERSION=$(echo "${JAVA_VERSION}" | awk -F'.' '{print $1}' )

# Determine the OS type for the URL
OS_TYPE="linux"
if [ "${OS}" = "alpine" ]; then
    OS_TYPE="alpine-linux"
fi
if [ "${OS}" = "windows" ]; then
    OS_TYPE="windows"
fi

# Loop over the array of architectures
for ARCH in ${ARCHS}; do
    # Fetch the download URL from the Adoptium API
    URL="https://mirrors.sustech.edu.cn/Adoptium/${VERSION}/jdk/${ARCH}/${OS_TYPE}/"
	
	PACKAGE=$(curl -s ${URL} | sed -n 's/.*>\([^<]*'"OpenJDK"'[^<]*\)<.*/\1/p')
	
	URL=${URL}${PACKAGE}

	curl --location --retry 5 --retry-connrefused --output /tmp/jdk.tar.gz ${URL}
done

if ! tar -xzf /tmp/jdk.tar.gz -C /opt/; then
    echo "Error: Failed to extract the JDK archive. Exiting with status 1." >&2
    exit 1
fi

EXTRACTED_DIR=$(tar -tzf /tmp/jdk.tar.gz | head -n 1 | cut -f1 -d"/")

if ! mv "/opt/${EXTRACTED_DIR}" "/opt/jdk-${JAVA_VERSION}"; then
    echo "Error: Failed to rename the extracted directory. Exiting with status 1." >&2
    exit 1
fi

if ! rm -f /tmp/jdk.tar.gz; then
    echo "Error: Failed to remove the downloaded archive. Exiting with status 1." >&2
    exit 1
fi
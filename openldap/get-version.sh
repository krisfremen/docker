#!/bin/bash
# Extract version information from OpenLDAP submodule
# Usage: ./get-version.sh [submodule-path]
# Outputs: tag, commit, version (can be used with GitHub Actions $GITHUB_OUTPUT)

set -e

SUBMODULE_PATH="${1:-openldap/upstream}"
OUTPUT_FILE="${GITHUB_OUTPUT:-/dev/stdout}"

if [ ! -d "$SUBMODULE_PATH" ]; then
    echo "Error: Submodule path '$SUBMODULE_PATH' does not exist" >&2
    exit 1
fi

cd "$SUBMODULE_PATH"

COMMIT=$(git rev-parse --short HEAD)

EXACT_TAG=$(git describe --tags --exact-match --match "OPENLDAP_REL_ENG_*" HEAD 2>/dev/null || echo "")

if [[ -n "$EXACT_TAG" ]]; then
    TAG="$EXACT_TAG"
else
    RELEASE_TAG=""
    for tag in $(git tag --list "OPENLDAP_REL_ENG_*" --sort=-creatordate | grep -E 'OPENLDAP_REL_ENG_[0-9]+_[0-9]+_[0-9]+$' | head -50); do
        if git merge-base --is-ancestor "$tag" HEAD 2>/dev/null; then
            RELEASE_TAG="$tag"
            break
        fi
    done
    
    if [[ -n "$RELEASE_TAG" ]]; then
        DISTANCE=$(git rev-list --count "${RELEASE_TAG}..HEAD" 2>/dev/null || echo "0")
        if [[ "$DISTANCE" -gt 0 ]]; then
            TAG="${RELEASE_TAG}-${DISTANCE}-g${COMMIT}"
        else
            TAG="$RELEASE_TAG"
        fi
    else
        MP_TAG=""
        for tag in $(git tag --list "OPENLDAP_REL_ENG_*" --sort=-creatordate | grep -E 'OPENLDAP_REL_ENG_[0-9]+_[0-9]+_[0-9]+_[A-Z]+' | head -20); do
            if git merge-base --is-ancestor "$tag" HEAD 2>/dev/null; then
                MP_TAG="$tag"
                break
            fi
        done
    fi
fi

# Extract version number from tag (e.g., OPENLDAP_REL_ENG_2_6_10 -> 2.6.10)
if [[ -n "$TAG" ]]; then
    if echo "$TAG" | grep -qE 'OPENLDAP_REL_ENG_([0-9]+)_([0-9]+)_([0-9]+)-([0-9]+)'; then
        VERSION=$(echo "$TAG" | sed -E 's/OPENLDAP_REL_ENG_([0-9]+)_([0-9]+)_([0-9]+)-([0-9]+).*/\1.\2.\3-\4/')
    elif echo "$TAG" | grep -qE 'OPENLDAP_REL_ENG_([0-9]+)_([0-9]+)_([0-9]+)$'; then
        VERSION=$(echo "$TAG" | sed -E 's/OPENLDAP_REL_ENG_([0-9]+)_([0-9]+)_([0-9]+).*/\1.\2.\3/')
    else
        VERSION=""
    fi
else
    VERSION=""
fi

# Output for GitHub Actions (if GITHUB_OUTPUT is set) or stdout
{
    echo "tag=${TAG}"
    echo "commit=${COMMIT}"
    echo "version=${VERSION}"
} >> "$OUTPUT_FILE"

# Also print to stderr for visibility
echo "Submodule tag: ${TAG:-none}" >&2
echo "Submodule version: ${VERSION:-none}" >&2
echo "Submodule commit: ${COMMIT}" >&2

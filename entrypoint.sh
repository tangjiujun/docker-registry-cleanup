#!/bin/bash

# Verify registry config.yml
: ${REGISTRY_CONFIG_FILE:="/etc/registry/config.yml"}
if [ ! -f ${REGISTRY_CONFIG_FILE} ]; then
    echo "ERROR: REGISTRY_CONFIG_FILE ${REGISTRY_CONFIG_FILE} doesn't exist"
    exit 1
fi

# Verify registry storage dir
: ${REGISTRY_STORAGE_DIR:=$(grep -A 2 'filesystem:' ${REGISTRY_CONFIG_FILE} | grep 'rootdirectory' | awk '{print $2}')}
REGISTRY_V2_BASE_DIR=${REGISTRY_STORAGE_DIR}/docker/registry/v2
if [ ! -d ${REGISTRY_V2_BASE_DIR} ]; then
    echo "ERROR: REGISTRY_V2_BASE_DIR ${REGISTRY_V2_BASE_DIR} doesn't exist"
    exit 1
fi

echo -e "\nStarting clean registry storage directory ${REGISTRY_STORAGE_DIR}"
cd ${REGISTRY_V2_BASE_DIR}

# Clean manifests without tags
find ./repositories -type f -name 'link' > /tmp/repo_links
MANIFESTS_WITHOUT_TAGS=$(comm -23 \
    <(grep '/_manifests/revisions/sha256/' /tmp/repo_links | grep -v '/signatures/sha256/' | awk -F/ '{print $(NF-1)}' | sort | uniq) \
    <(for f in $(grep '/_manifests/tags/.*/current/link' /tmp/repo_links); do cat ${f} | sed 's/^sha256://g'; echo; done | sort | uniq))
echo -e "\n$(echo ${MANIFESTS_WITHOUT_TAGS} | wc -w | tr -d ' ') manifests to be deleted"
for manifest in ${MANIFESTS_WITHOUT_TAGS}; do
    links=$(grep "/_manifests/revisions/sha256/${manifest}/link" /tmp/repo_links)
    for link in ${links}; do
        rm -f ${link}
        echo "Deleted ${link}"
    done
done
find ./repositories -mindepth 6 -type d -empty | grep '/_manifests/revisions/sha256/' | xargs -r rmdir

# Clean outdated blobs
echo ""
/bin/registry garbage-collect $REGISTRY_CONFIG_FILE | grep 'eligible for deletion' | awk -F 'marked, ' '{print $(NF)}'
find ./blobs/sha256 -mindepth 1 -type d -empty | xargs -r rmdir

# Clean outdated indexes
find ./repositories -mindepth 5 -type d -empty | grep '/_manifests/revisions/sha256/' | xargs -r rmdir
find ./repositories -type f -name 'link' > /tmp/repo_links
OUTDATED_INDEX_SHA256=$(comm -23 \
    <(grep '/_manifests/tags/.*/index/sha256' /tmp/repo_links | awk -F/ '{print $(NF-1)}' | sort | uniq) \
    <(grep '/_manifests/revisions/sha256/' /tmp/repo_links | grep -v '/signatures/sha256/' | awk -F/ '{print $(NF-1)}' | sort | uniq))
echo -e "\n$(echo ${OUTDATED_INDEX_SHA256} | wc -w | tr -d ' ') indexes to be deleted"
for sha256 in ${OUTDATED_INDEX_SHA256}; do
    links=$(grep "/_manifests/tags/.*/index/sha256/${sha256}/link" /tmp/repo_links)
    for link in ${links}; do
        rm -f ${link}
        echo "Deleted ${link}"
    done
done
find ./repositories -mindepth 8 -type d -empty | grep '/_manifests/tags/.*/index/sha256/' | xargs -r rmdir

# Clean outdated layers
find ./repositories -type f -name 'link' > /tmp/repo_links
OUTDATED_LAYERS=$(comm -23 \
    <(grep '/_layers/sha256/' /tmp/repo_links | awk -F/ '{print $(NF-1)}' | sort | uniq) \
    <(find ./blobs/sha256 -type f -name 'data' | awk -F/ '{print $(NF-1)}' | sort))
echo -e "\n$(echo ${OUTDATED_LAYERS} | wc -w | tr -d ' ') layers to be deleted"
for layer in ${OUTDATED_LAYERS}; do
    links=$(grep "/_layers/sha256/${layer}/link" /tmp/repo_links)
    for link in ${links}; do
        rm -f ${link}
        echo "Deleted ${link}"
    done
done
find ./repositories -mindepth 5 -type d -empty | grep '/_layers/sha256/' | xargs -r rmdir

# Delete find results cache file
rm -f /tmp/repo_links
echo -e "\nFinished clean registry storage directory ${REGISTRY_STORAGE_DIR}\n"

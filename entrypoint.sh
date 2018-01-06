#!/bin/bash

# Verify registry url
REGISTRY_URL=${REGISTRY_URL%/}
if test -z "${REGISTRY_URL}"; then
    echo "ERROR: REGISTRY_URL doesn't exist"
    exit 1
fi

# Verify registry dir
: ${REGISTRY_DIR:="/registry"}
REGISTRY_V2_BASE_DIR=${REGISTRY_DIR}/docker/registry/v2
if [ ! -d ${REGISTRY_V2_BASE_DIR} ]; then
    echo "ERROR: REGISTRY_V2_BASE_DIR '${REGISTRY_V2_BASE_DIR}' doesn't exist"
    exit 1
fi

# Verify reg cli
reg ${REG_GLOBAL_OPTS} -r ${REGISTRY_URL} ls > /dev/null
if [ ! $? -eq 0 ]; then
    echo "ERROR: Execute 'reg ${REG_GLOBAL_OPTS} -r ${REGISTRY_URL} ls' failed"
    exit 1
fi

echo "Starting clean registry ${REGISTRY_URL} directory ${REGISTRY_DIR}"
cd ${REGISTRY_V2_BASE_DIR}

# Clean manifests without tags
find ./repositories -type f -name 'link' > /tmp/repo_links
MANIFESTS_WITHOUT_TAGS=$(comm -23 \
    <(grep '/_manifests/revisions/sha256/' /tmp/repo_links | grep -v '/signatures/sha256/' | awk -F/ '{print $(NF-1)}' | sort | uniq) \
    <(for f in $(grep '/_manifests/tags/.*/current/link' /tmp/repo_links); do cat ${f} | sed 's/^sha256://g'; echo; done | sort | uniq))
echo -e "\n$(echo ${MANIFESTS_WITHOUT_TAGS} | wc -w | tr -d ' ') manifests to be deleted"
for manifest in ${MANIFESTS_WITHOUT_TAGS}; do
    repos=$(grep "/_manifests/revisions/sha256/${manifest}/link" /tmp/repo_links | awk -F/ '{print $3"/"$4}')
    for repo in ${repos}; do
        reg ${REG_GLOBAL_OPTS} -r ${REGISTRY_URL} rm ${repo}@sha256:${manifest}
    done
done

# Clean outdated blobs
echo ""
/bin/registry garbage-collect /etc/registry/config.yml | grep 'eligible for deletion' | awk -F 'marked, ' '{print $(NF)}'
# Clean empty directories in ./blob/sha256
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

if [ "${CLEAN_UPLOADS}" == "true" ]; then
    # Clean outdated uploads
    OUTDATED_UPLOADS=$(find ./repositories -type d -name 'hashstates' | grep '/_uploads/.*/hashstates' | sed 's#/hashstates##')
    echo -e "\n$(echo ${OUTDATED_UPLOADS} | wc -w | tr -d ' ') uploads to be deleted"
    for upload in $OUTDATED_UPLOADS; do
        rm -rf ${upload}
        echo "Deleted ${upload}"
    done
fi

echo -e "\nFinished clean registry ${REGISTRY_URL} directory ${REGISTRY_DIR}"

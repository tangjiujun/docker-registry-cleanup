### Description

> Clean up docker registry images without tags. Only support registry that stored with filesystem.

### Warning

You can't enable registry cache. Because we clean up image layers from filesystem directly, this will cause cache not be right.

### Usage

Run `docker run -it --rm --volumes-from registry cleanup`

### Configuration：

You can config registry config file and storage directory by set docker environment variables.

* `CONFIG_FILE` default is `/etc/registry/config.yml`
* `STORAGE_DIR` default parse filesystem's rootdirectory from `CONFIG_FILE`

If you want to clean up upload directory, you can config as below.

```yaml
storage:
  maintenance:
    uploadpurging:
      enabled: true
      age: 168h
      interval: 24h
      dryrun: false
```

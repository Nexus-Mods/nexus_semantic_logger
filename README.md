# nexus_semantic_logger

Configures a [semantic_logger](https://rubygems.org/gems/rails_semantic_logger) as required for NexusMods components.

# Local gem development

Steps to run this gem from local sources in one the nexus 'staged build' rails components:

## Copy gem sources to component

```
cd ~/legacy/users
cp -r ../nexus_semantic_logger .
```

## Adjust component Dockerfile to include gem sources

Within stage 1, append a COPY after the Gemfile copy:

```
COPY --chown=nexus:nexus Gemfile* ./
COPY --chown=nexus:nexus nexus_semantic_logger/ ./nexus_semantic_logger/
```

Within stage 2, append a COPY after the bundle copy:

```
COPY --from=stage1 /usr/local/bundle /usr/local/bundle
COPY --from=stage1 /app/nexus_semantic_logger/ /app/nexus_semantic_logger/
```

## Adjust Gemfile to use local path

```
gem 'nexus_semantic_logger', :path => "/app/nexus_semantic_logger"


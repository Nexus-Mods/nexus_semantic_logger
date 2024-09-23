# nexus_semantic_logger

Configures a [semantic_logger](https://rubygems.org/gems/rails_semantic_logger) as required for NexusMods components.

## Telemetry

As well as providing a semantic logger, this gem handles datadog telemetry associated with the logging approach:

* logs
* traces
* metrics
    * statsd is automatically attached to datadog runtime metrics and may also be used for custom metrics.
    * `ResponseCodeStatsMiddleware` is included to capture response code metrics from rack applications

### Customise log level per logger

For example, to show debug logging for `MySubscriber` while having all other logs on info.

```
# The log level must be set to the lowest level which can be dynamically controlled.
LOG_LEVEL=DEBUG
# The default level for filtered logs.
LOG_NAMES_DEFAULT_LEVEL=INFO
# Per level overrides for filtered logs.
LOG_NAMES_DEBUG=MySubscriber
```

* Customised log names are available for each level e.g. `LOG_NAMES_TRACE`
* Log names are matched on prefix.
* Multiple log names are supported via comma separated values.

### Changing log level dynamically

The default level for filtered logs (`LOG_NAMES_DEFAULT_LEVEL`) may be changed on a running instance with the `WINCH`
signal. This cycles through the available levels `[trace debug info warn error fatal]`.

Note that you cannot dynamically enable a level lower than the `LOG_LEVEL`. Instead the env var must be adjusted and the
instance restarted.

Send signal: `pkill --signal WINCH --count --full "^puma.*"`

Instance output: `WINCH signal changed LOG_NAMES_DEFAULT_LEVEL from debug to info`

### Querying current log level

The `SYS` signal will print the levels used by the running instance.

Send signal: `pkill --signal SYS --count --full "^puma.*"`

Instance output: `SYS signal reports LOG_LEVEL=debug LOG_NAMES_DEFAULT_LEVEL=warn`

### Sending metrics

Ensure the metric name is in the format: `nexus.{component}.{major}.{minor}`

Where _major and minor_ are specific to the component logic e.g. `nexus.uploads.clamscan.pass`

For example, to increment a count:

```
NexusSemanticLogger.metrics.increment('nexus.users.registration.complete')
```

### Rack response code metrics
This can be configured with a middleware in application.rb

```
config.middleware.use ResponseCodeStatsMiddleware
```

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


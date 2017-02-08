# ossec-server

An ossec-server image with the ability to separate the ossec configuration/data from the container, meaning easy container replacements. This image is designed to be as turn key as possible, supporting out of the box:

1. Automatic enrollment for agents, using ossec-authd
2. Remote syslog forwarding for the ossec server messages
3. SMTP notifications _(requires no-auth SMTP server)_


The following directories are externalized under `/var/ossec/data` which allow the container to be replaced without configuration or data loss: `logs`, `etc`, `stats`,`rules`, and `queue`. In addition to those directories, the `bin/.process_list` file is symlink'ed to `process_list` in the data volume.

## Quick Start

To get an up and running ossec server that supports auto-enrollment and sends HIDS notifications a syslog server, use.

```
 docker run --name ossec-server -d -p 1514:1514/udp -p 1515:1515\
  -e SYSLOG_FORWADING_ENABLED=true -e SYSLOG_FORWARDING_SERVER_IP=X.X.X.X\
  -v /somepath/ossec_mnt:/var/ossec/data xetusoss/ossec-server
```

Once the system starts up, you can execute the standard ossec commands using docker. For example, to list active agents.

```
docker exec -ti ossec-server /var/ossec/bin/list_agents -a
```

## Available Configuration Parameters

* __AUTO_ENROLLMENT_ENABLED__: Specifies whether or not to enable auto-enrollment via ossec-authd. Defaults to `true`;
* __AUTHD_OPTIONS__: Options to passed ossec-authd, other than -p and -g. Defaults to empty;
* __SMTP_ENABLED__: Whether or not to enable SMTP notifications. Defaults to `true` if ALERTS_TO_EMAIL is specified, otherwise `false`
* __SMTP_RELAY_HOST__: The relay host for SMTP messages, required for SMTP notifications. This host must support non-authenticated SMTP ([see this thread](https://ossec.uservoice.com/forums/18254-general/suggestions/803659-allow-full-confirguration-of-smtp-service-in-ossec)). No default.
* __ALERTS_FROM_EMAIL__: The email address the alerts should come from. Defaults to `ossec@$HOSTNAME`.
* __ALERTS_TO_EMAIL__: The destination email address for SMTP notifications, required for SMTP notifications. No default.
* __SYSLOG_FORWADING_ENABLED__: Specify whether syslog forwarding is enabled or not. Defaults to `false`.
* __SYSLOG_FORWARDING_SERVER_IP__: The IP for the syslog server to send messagse to, required for syslog fowarding. No default.
* __SYSLOG_FORWARDING_SERVER_PORT__: The destination port for syslog messages. Default is `514`.
* __SYSLOG_FORWARDING_FORMAT__: The syslog message format to use. Default is `default`.

**Please note**: All the SMTP and SYSLOG configuration variables are only applicable to the first time setup. Once the container's data volume has been initialized, all the configuration options for OSSEC can be changed.

## Known Issues / Warnings

#### ossec-execd is not enabled

Since this is a docker container, ossec-execd really isn't a great idea anyway. Having a log server, such as graylog, react based on log entries is the recommended approach.

#### A default localhost agent is added

On first launch, the ossec server will not start up properly and bind to port 1514, unless at least one agent to be present in the client.keys file. To avoid that issue, a local agent is setup by default. See [this bug](https://groups.google.com/forum/#!topic/ossec-list/qeC_h3EZCxQ) with OSSEC.

#### Running on OS X using Docker For Mac

The [osxfs integration](https://docs.docker.com/docker-for-mac/osxfs/) used for volume binding on Mac OS X causes an issue resolving symlinks in the container. To work around this issue, just don't bind `/var/ossec/data` to a host directory. Instead, use a regular docker volume and execute a shell in the container to inspect the data. All the typical docker volume management tricks apply, of course.

```
# To start the container on OS X
docker run --name ossec-server -d -p 1514:1514/udp -p 1515:1515\
  -e SYSLOG_FORWADING_ENABLED=true -e SYSLOG_FORWARDING_SERVER_IP=X.X.X.X\
  -v /var/ossec/data xetusoss/ossec-server
```


## Issues /   Pull Requests

Since this image has become the de-facto standard for OSSEC on docker hub, I wanted to be very clear that we intend to maintain this image with the interest of the community in mind. If you have issues, please file them. If you have made changes you'd like to see included, pull requests are welcome!

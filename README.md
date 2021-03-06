fluent-plugin-remote-syslog
===========================

fluentd plugin for streaming logs out to a remote syslog server or syslog SaaS service (like Papertrail)

#Available Plugins:
* out_syslog: registers itself as "syslog", and is the non-buffered implementation, communicating through UDP
* out_syslog_buffered: registers itself as "syslog_buffered", and is the buffered implementation, communicating through TCP

#Plugin Settings:
Both plugins have the same configuration options:

* remote_syslog: fqdn or ip of the remote syslog instance
* port: the port, where the remote syslog instance is listening
* hostname: hostname to be set for syslog messages
* remove_tag_prefix: remove tag prefix for tag placeholder. 
* tag_key: use the field specified in tag_key from record to set the syslog key
* tag_max_size: Truncate the key value to that number. Defaults to 32, because to to RFC. Might work with longer tags, depending on the syslog implementation.
* msg_max_size: Truncate the whole message that is sent over the wire. RFC allows 1024 chars. Might work with longer tags, depending on the syslog implementation.
* facility: Syslog log facility
* severity: Syslog log severity
* use_record: Use severity and facility from record if available
* payload_key: Use the field specified in payload_key from record to set payload
* payload_full: Set this to true and the full record will be sent to remote syslog , JSON encoded.

#Configuration example:
```
<match site.*>
  type syslog_buffered
  remote_syslog your.syslog.host
  port 514
  hostname ${hostname}
  facility local0
  severity debug
</match>
```

#Building and Installing:
```
git clone https://github.com/docebo/fluent-plugin-remote-syslog
cd fluent-plugin-remote-syslog
gem build fluent-plugin-remote-syslog.gemspec
# In case of td-agent:
/usr/sbin/td-agent-gem install /tmp/fluent-plugin-remote-syslog-*.gem
```

Contributors:

* Andrea Spoldi 
* [deathowl](http://github.com/deathowl)
* Andreas John (himself (at) derjohn.de)

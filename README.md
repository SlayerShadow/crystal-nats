# Crystal NATS

The [Crystal](https://crystal-lang.org) client for the [NATS Messaging System](https://nats.io).

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  nats:
    github: SlayerShadow/crystal-nats
```

## Basic usage

* Because of the module doesn't know which data will be received (text? binary?), the incoming "message" type is always set to Bytes (see [Crystal Thread](https://github.com/crystal-lang/crystal/issues/1681) for more details).

```crystal
require "nats"

client = NATS::Client.new
# There can be passed options (see below)
client.connect

# Simple subscription (message: Bytes)
client.subscribe("foo"){ |message| puts "Message: #{ String.new message }" }

# Unsubscribe
sid = client.subscribe("foo"){ |message| puts "Message: #{ String.new message }" }
cluent.unsubscribe sid

# Reply (message: Bytes, reply: String)
client.subscribe("foo"){ |message, reply| puts "Replying to: #{ reply }" }

# Matches subject (message: Bytes, reply: String, subject: String)
client.subscribe("foo.*"){|message, reply, subject|
  puts "Receiving from: #{ subject }"
}

# Publish into the channel (channel: String, message: String)
client.publish("foo", "bar")

# Publish with reply (channel: String, message: String, reply: String)
client.publish("foo", "bar", "foo.repl")
```

## Clustered usage (not fully implemented)

```crystal
require "nats"

options = {
  :servers => [ "nats://localhost:4222", "nats://localhost:4223" ],
  :randomize_servers => true, # Should servers be chosen randomly
  :reconnect => true, # Tries to reconnect to server after failed attempt
  :max_reconnect_attempts => 10u8, # How many times try to reconnect before exception
  :reconnect_time_wait => 2u8, # Delay between reconnection tries
  :verbose => true # if need to confirm that sent is succeeded
}

client = NATS::Client.new
client.connect options

client.subscribe("foo"){|message, reply, subject|
  # Do something
}
```

## Authentication

```crystal
require "nats"

options = {
  :servers => [ "nats://localhost:4222" ],
  :user => "name",
  :pass => "helloworld"
}

client = NATS::Client.new
client.connect options
```

## TLS

```crystal
require "nats"

options = {
  :servers => [ "tls://localhost:4444" ],
  :tls => {
    :cert_file => "config/cert.pem",
    :cert_key_file => "config/cert/key.pem",
    :ca_cert_file => "config/ca.pem", # When need to verify peer
    :verify_peer => false             # Along with ca_cert_file - when need to verify peer (default - false)
  }
}

client = NATS::Client.new
client.connect options
```

Note that:

- If NATS launched with `-tlsverify`
    - It should be also launched with at least `-tlscert`, `-tlskey` and `-tlscacert`.
    - App should be started with at least `:cert_key_file` and `:ca_cert_file`.
- If NATS launched without `tlsverify`
    - It can be also launched without `-tlscacert`.
    - App can be started even without `:tls` key (protocol will be switched to TLS transparently).
- If app launches with `:verify_peer => true`
    - NATS can be launched without `-tlscacert` but the `-tlscert` and `-tlskey` should be passed.
    - App should be started with `:ca_cert_file` to verify NATS.
    - App can be started without `:cert_file` and `:cert_key_file` (only CA is mandatory).
- If NATS launched with `-tlsverify` and app launches with `:verify_peer => true`
    - NATS and app should be fully configured for TLS connection.

## Development

### Features

- [x] Exchange server messages
    - [ ] Tests
- [x] Clusterization
    - [ ] Tests
- [x] Publish/Subscribe
    - [ ] on_error callback
    - [ ] on_disconnect callback
    - [ ] on_reconnect callback
    - [ ] on_close callback
    - [ ] Tests
- [x] Unsubscribe
    - [ ] Unsubscribe after receiving amount of messages
    - [ ] Tests
- [x] Reconnect after critical errors
    - [ ] Tests
- [x] User authentication
    - [ ] Tests
- [x] OpenSSL
    - [x] Connect with using certificates
    - [x] Manage server information to determine when to connect through SSL
    - [ ] Tests
- [ ] Subscriptions timeouts
    - [ ] Tests

### Improvements

- [ ] Make the "options" flexible
    - [x] Hash
    - [ ] JSON::Any
    - [ ] YAML::Any
        - [ ] Require yaml in macros and only when it needed (lazy)
- [ ] Add configuration for channel buffer (see [Crystal thread](https://github.com/crystal-lang/crystal/issues/5375))

### Performance

- [ ] Remove regex from parser
- [ ] Manage `Bytes` only, even when receive protocol commands

## Contributing

1. Fork it ( https://github.com/SlayerShadow/crystal-nats/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [SlayerShadow](https://github.com/SlayerShadow) Dmitry Lykov - creator, maintainer

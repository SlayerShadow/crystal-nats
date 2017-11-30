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

## Authentication (not yet implemented)

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

## TLS (not yet implemented)

```crystal
require "nats"

options = {
  :servers => [ "tls://localhost:4444" ],
  :tls => {
    :private_key_file => "config/cert/key.pem",
    :cert_file => "config/cert.pem",
    :ca_cert_file => "config/ca.pem", # When need to verify peer
    :verify_peer => true # Along with ca_cert_file - when need to verify peer
  }
}

client = NATS::Client.new
client.connect options
```

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
- [ ] User authentication
    - [ ] Tests
- [ ] OpenSSL:
    - [ ] Connect with using certificates
    - [ ] Manage server information to determine when to connect through SSL
    - [ ] Require OpenSSL in macros and only when it needed (lazy)
    - [ ] Tests
- [ ] Subscriptions timeouts
    - [ ] Tests

### Improvements

- [ ] Make the "options" flexible:
    - [x] Hash
    - [ ] JSON::Any
    - [ ] YAML::Any
        - [ ] Require yaml in macros and only when it needed (lazy)

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

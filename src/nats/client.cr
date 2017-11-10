require "uri"
require "json"
require "./client/*"

module NATS

	class Client
		@parser : Protocol::Parser?
		@options : OptionsHash?
		@servers : ServerPoolArray = ServerPoolArray.new
		@server_info : ServerInfoHash = ServerInfoHash.new
		@status : UInt8 = STATUSES[ :disconnected ]
		@subscriptions : SubscriptionsHash = SubscriptionsHash.new
		@uri : URI?

		getter server_info
		getter status

		def initialize
			@parser = Protocol::Parser.new self
		end

		def connect(opts : Hash? = OptionsHash.new) : Void
			set_options opts

			initialize_servers

			# Crystal does not have "retry" so try to get around it
			# See https://github.com/crystal-lang/crystal/issues/1736
			loop{
				begin
					server = next_server
					initialize_connection server
					setup_protocol

					# Successfully connected. Reset to defaults
					server[ :auth_required ] ||= true if @server_info[ "auth_required" ]
					server[ :reconnect_attempts ] = 0_u8

					break
				rescue error : Exceptions::NoServersException
					raise error
				rescue error
					close_connection
					sleep options[ :reconnect_time_wait ].as( UInt8 ) if options[ :reconnect_time_wait ]
				end
			}

			create_spawns

			@status = STATUSES[ :connected ]
		end

		def publish(channel : String, message : String = EMPTY_MESSAGE, reply : String? = nil) : Void
			return if message == EMPTY_MESSAGE
			message_size = message.bytesize
			reply_substring = reply ? "#{ reply } " : ""
			connection.write "PUB #{ channel } #{ reply_substring }#{ message_size }#{ CR_LF }#{ message }#{ CR_LF }"
		end

		def subscribe(channel : String, id : UInt64? = nil, options : Subscription::OptionsHash = Subscription::OptionsHash.new, &callback : Subscription::CallbackProc) : UInt64
			subscription = Subscription.new channel, connection, id, options, &callback
			@subscriptions[ subscription.id ] = subscription
			subscription.id
		end

		def unsubscribe(id : UInt64) : Void
			subscription = @subscriptions[ id ]
			subscription.unsubscribe
			@subscriptions.delete id
		end

		def process_info(info : String) : Void
			json_parser = JSON::PullParser.new info
			@server_info = ServerInfoHash.new json_parser
		end

		def process_msg(group : String, subscription_id : UInt64, reply : String, message : Bytes) : Void
			if subscription = @subscriptions[ subscription_id ]
				subscription.callback.call message, reply, group
			end
		end

		def process_ping : Void
			connection.write "PONG#{ CR_LF }"
		end

		def process_pong : Void
			# TODO: Handle pong from servers (manual ping sent?)
		end

		def process_error(error : String) : Void
			# TODO: Handle protocol errors
			puts "\e[31mCatched protocol error: #{ error }!\e[0m"
		end

		def close_connection : Void
			case @status
			when STATUSES[ :connecting ] then connection.disconnect
			when STATUSES[ :connected ]
				@status = STATUSES[ :disconnecting ]
				connection.disconnect
			end

			@status = STATUSES[ :disconnected ]
		end

		private def set_options(opts : Hash) : Void
			inner_options = OptionsHash.new

			inner_options[ :servers ] = opts[ :servers ]? || [ DEFAULT_URL ]

			inner_options[ :verbose ] = opts[ :verbose ]? || false
			inner_options[ :pedantic ] = opts[ :pedantic ]? || false

			inner_options[ :randomize_servers ] = opts[ :randomize_servers ]?.nil? ? true : opts[ :randomize_servers ]
			inner_options[ :reconnect_time_wait ] ||= RECONNECT_TIME_WAIT
			inner_options[ :max_reconnect_attempts ] ||= MAX_RECONNECT_ATTEMPTS

			@options = inner_options
		end

		private def initialize_servers : Void
			servers = options[ :servers ].as Array( String )
			servers.shuffle! if options[ :randomize_servers ]
			servers.each{ |server_url| @servers << ServerHash{ :uri => URI.parse( server_url ) } }
		end

		private def next_server : ServerHash
			server = @servers.shift

			reconnects = ( server[ :reconnect_attempts ]? || 0_u8 ).as( UInt8 ) + 1
			server[ :reconnect_attempts ] = reconnects

			@servers << server if reconnects < options[ :max_reconnect_attempts ].as( UInt8 )

			set_uri_credentials server[ :uri ].as( URI )

			server
		rescue IndexError
			raise Exceptions::NoServersException.new
		end

		private def set_uri_credentials(uri : URI) : Void
			uri.user     = options[ :user ].as String if options[ :user ]?
			uri.password = options[ :pass ].as String if options[ :pass ]?
			@uri = uri
		end

		private def initialize_connection(server : ServerHash) : Void
			if @connection
				connection.reinitialize @uri.not_nil!
			else
				@connection = Connection.new @uri.not_nil!
			end

			connection.connect

			server[ :was_connected ] = true
			@status = STATUSES[ :connecting ]
		end

		private def setup_protocol : Void
			parser.parse connection.read_command.not_nil!
			raise Protocol::Exceptions::ConnectException.new "INFO not received" unless @server_info

			connection.write connect_command

			if options[ :verbose ]
				command = connection.read_command raise_exception: true
				raise Protocol::Exceptions::ConnectException.new "Unexpected command received: '#{ command }', expecting +OK" if command !~ Protocol::OK
			end
		rescue error : Protocol::Exceptions::ErrCommandException
			raise @server_info[ "auth_required" ]? ? Protocol::Exceptions::AuthorizationViolationException.new : error
		end

		private def connect_command : String
			data = Hash{
				:verbose  => options[ :verbose ],
				:pedantic => options[ :pedantic ],
				:lang     => LANG,
				:version  => VERSION,
				:protocol => PROTOCOL
			}
			data[ :name ] = options[ :name ] if options[ :name ]?

			"CONNECT #{ data.to_json }#{ CR_LF }"
		end

		private def create_spawns : Void
			spawn read_loop
		end

		private def read_loop : Void
			loop{
				command = connection.read_command

				# disconnected, try to connect again depending on settings
				# TODO: Replace to "process_error" to increase performance
				unless command
					connect options
					break
				end

				parser.parse command
				parser.parse connection.read_data( parser.needed ) if parser.need_data?
			}
		end

		private def connection : Connection
			@connection.not_nil!
		end

		private def parser : Protocol::Parser
			@parser.not_nil!
		end

		private def options : OptionsHash
			@options.not_nil!
		end
	end

end

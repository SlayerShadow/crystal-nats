require "uri"
require "json"
require "./client/*"

module NATS

	class Client
		@connection : Connection?
		@parser : Protocol::Parser?
		@options : OptionsHash?
		@servers : ServerPoolArray = ServerPoolArray.new
		@server_info : ServerInfoHash?
		@status : UInt8 = STATUSES[ :disconnected ]
		@subscriptions : SubscriptionsHash = SubscriptionsHash.new
		@uri : URI?

		@signal_channel : Channel( SIGNALS ) = Channel( SIGNALS ).new

		@last_connection_exception : Exception?

		getter server_info
		getter status

		def initialize
			@parser = Protocol::Parser.new self
		end

		def connect(opts : Hash = OptionsHash.new) : Void
			set_options opts
			reconnect true
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

		def process_error(message : String) : Void
			# TODO: Handle callback error with specific class and message
			error = case message
			when "Authorization Violation" then Protocol::Exceptions::AuthorizationViolationException.new
			else Protocol::Exceptions::ErrCommandException.new message
			end

			# Fibers cannot be stopped, try to get around
			# See https://github.com/crystal-lang/crystal/issues/3561
			spawn{
				@signal_channel.receive
				if connected? && options[ :reconnect ]
					@status = STATUSES[ :reconnecting ]
					connection.disconnect
					reconnect
				end
			}
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

		def disconnected? : Bool
			@status == STATUSES[ :disconnected ]
		end

		def connecting? : Bool
			@status == STATUSES[ :connecting ] || @status == STATUSES[ :reconnecting ]
		end

		def reconnecting? : Bool
			@status == STATUSES[ :reconnecting ]
		end

		def connected? : Bool
			@status == STATUSES[ :connected ]
		end

		def disconnecting? : Bool
			@status == STATUSES[ :disconnecting ]
		end

		private def set_options(opts : Hash) : Void
			# To keep the user interaction simple,
			# and avoid to initialize options through the NATS::OptionsHash in the main app,
			# and keep the user options more or less dynamic,
			# and keep internal options statically typed
			# it needs helper hash with required static type.
			# TODO: Make it clean.
			inner_options = OptionsHash.new

			inner_options[ :servers ] = opts[ :servers ]? || [ DEFAULT_URL ]
			inner_options[ :reconnect ] = opts[ :reconnect ]?.nil? ? true : opts[ :reconnect ]

			inner_options[ :verbose ] = opts[ :verbose ]? || false
			inner_options[ :pedantic ] = opts[ :pedantic ]? || false

			inner_options[ :randomize_servers ] = opts[ :randomize_servers ]?.nil? ? true : opts[ :randomize_servers ]
			inner_options[ :reconnect_time_wait ] = opts[ :reconnect_time_wait ]? || RECONNECT_TIME_WAIT
			inner_options[ :max_reconnect_attempts ] = opts[ :max_reconnect_attempts ]? || MAX_RECONNECT_ATTEMPTS

			inner_options[ :user ] = opts[ :user ] if opts[ :user ]?
			inner_options[ :pass ] = opts[ :pass ] if opts[ :pass ]?

			@options = inner_options
		end

		private def reconnect(first_time : Bool = false) : Void
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
					raise @last_connection_exception || error
				rescue error
					@last_connection_exception = error

					close_connection

					if first_time && !options[ :reconnect ]
						# TODO: Call disconnect callback here
						raise error
					end

					sleep options[ :reconnect_time_wait ].as( UInt8 ) if options[ :reconnect_time_wait ]
				end
			}

			create_spawns

			@status = STATUSES[ :connected ]

			@subscriptions.each{ |id, subscription| subscription.subscribe } unless first_time
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
				connection.uri = @uri.not_nil!
			else
				@connection = Connection.new @uri.not_nil!
			end

			connection.connect

			server[ :was_connected ] = true
			@status = STATUSES[ :connecting ]
		end

		private def setup_protocol : Void
			if command = connection.read_command
				parser.parse command
			end

			raise Protocol::Exceptions::ConnectException.new "INFO not received" unless @server_info

			handle_connect_command

		rescue error : Protocol::Exceptions::ErrCommandException
			raise @server_info[ "auth_required" ]? ? Protocol::Exceptions::AuthorizationViolationException.new : error
		end

		private def handle_connect_command : Void
			data = Hash{
				:verbose  => options[ :verbose ],
				:pedantic => options[ :pedantic ],
				:lang     => LANG,
				:version  => VERSION,
				:protocol => PROTOCOL
			}
			data[ :name ] = options[ :name ] if options[ :name ]?

			if @server_info[ "auth_required" ]
				data[ :user ] = options[ :user ]?
				data[ :pass ] = options[ :pass ]?
			end

			connection.write "CONNECT #{ data.to_json }#{ CR_LF }#{ PING_COMMAND }"
			command = connection.read_command

			raise Protocol::Exceptions::ErrCommandException.new command if command =~ Protocol::ERR
			raise Exceptions::EmptyCommandException.new unless command

			if options[ :verbose ]
				command = connection.read_command
				raise Protocol::Exceptions::ConnectException.new "Unexpected command received: #{ command.inspect }, expecting \"PONG\\r\\n\"" if command !~ Protocol::PONG
			end
		end

		private def create_spawns : Void
			spawn read_loop
		end

		private def read_loop : Void
			# Fibers cannot be stopped, try to get around
			# See https://github.com/crystal-lang/crystal/issues/3561
			while command = connection.read_command
				parser.parse command
				parser.parse connection.read_data( parser.needed ) if parser.need_data?
			end

			@signal_channel.send SIGNALS::CLOSE_READ
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

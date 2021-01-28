module NATS

	module Protocol

		class Parser
			@group           : String     = ""
			@reply           : String     = ""
			@subscription_id : UInt64     = 0_u64
			@needed          : UInt32     = 0_u32

			getter needed

			def initialize(@client : NATS::Client)
			end

			def reset : Void
				@group           = ""
				@reply           = ""
				@subscription_id = 0_u64
				@needed          = 0_u32
			end

			def parse(command : String) : Void
				# TODO: Replace regexp to increase performance
				case command
				when MSG
					@group    = $1
					@subscription_id = $2.to_u64
					@reply           = $3? ? $3 : ""
					@needed          = $4.to_u32
				when OK
				when ERR then @client.process_error $1
				when PING then @client.process_ping
				when PONG then @client.process_pong
				when INFO then @client.process_info $1
				when UNKNOWN then @client.process_error "Unknown protocol: #{ $1 }"
				end
			end

			def parse(data : Bytes) : Void
				@needed -= data.size
				@client.process_msg @group, @subscription_id, @reply, data
			end

			def need_data? : Bool
				@needed > 0
			end
		end

	end

end

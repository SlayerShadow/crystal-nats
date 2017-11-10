module NATS

	class Client
		class Subscription
			alias OptionsHash = Hash(Symbol, String | UInt32)
			# TODO: Make callbacks simpler
			alias CallbackProc = Proc(Bytes, String, String, Void)

			@@current_id = 0_u64

			@socket : Connection
			@callback : CallbackProc
			@id : UInt64
			@receives_count : UInt32 = 0_u32
			@group : String?
			@max_receives : UInt32?

			getter :id, :callback

			def initialize(channel : String, @socket, id : (UInt64 | UInt32)?, options, &@callback : Subscription::CallbackProc)
				if current_id = id.try &.to_u64
					@id = current_id
					@@current_id = current_id
				else
					@id = @@current_id += 1_u64
				end

				@group = options[ :group ].as String if options[ :group ]?
				@max_receives = options[ :max_receives ].as UInt32 if options[ :max_receives ]?

				@socket.write "SUB #{ channel } #{ @id }#{ CR_LF }"
			end

			def unsubscribe : Void
				@socket.write "UNSUB #{ @id }#{ CR_LF }"
			end
		end
	end

end

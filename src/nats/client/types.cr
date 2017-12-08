module NATS

	class Client
		enum SIGNALS
			CLOSE_READ
		end

		alias OptionsTLSHash = Hash(Symbol, String | Bool)
		alias OptionsHash = Hash(Symbol,
			OptionsTLSHash |             # :tls
			Array(String) |              # :servers
			String |                     # :user, :pass
			UInt8 |                      # :max_reconnect_attempts, :reconnect_time_wait
			Bool |                       # :randomize_servers, :reconnect, :verbose
			Nil
		)

		alias ServerHash = Hash(Symbol, URI | UInt8 | Bool | Nil)
		alias ServerPoolArray = Array(ServerHash)
		alias ServerInfoHash = Hash(String, String | UInt32 | Bool)

		alias SubscriptionsHash = Hash(UInt64, Subscription)
	end

end

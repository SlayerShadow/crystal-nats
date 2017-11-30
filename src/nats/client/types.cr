module NATS

	class Client
		enum SIGNALS
			CLOSE_READ
		end

		alias OptionsHash = Hash(Symbol,
			Array(String) | String | UInt8 | Bool | Nil
		)

		alias ServerHash = Hash(Symbol, URI | UInt8 | Bool | Nil)
		alias ServerPoolArray = Array(ServerHash)
		alias ServerInfoHash = Hash(String, String | UInt32 | Bool)

		alias SubscriptionsHash = Hash(UInt64, Subscription)
	end

end

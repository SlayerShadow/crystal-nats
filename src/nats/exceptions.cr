module NATS

	module Exceptions

		class NoServersException < Exception
			def initialize
				super "No servers available"
			end
		end

		class ConnectionInitializationException < Exception
			def initialize
				super "Trying reinitialize connection with established socket connection"
			end
		end

		class EmptyCommandException < Exception
			def initialize
				super "No commands received. Server lost?"
			end
		end

	end

end

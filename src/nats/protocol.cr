module NATS

	module Protocol

		# TODO: Replace regexp to increase performance
		MSG     = /\AMSG\s+([^\s]+)\s+([^\s]+)\s+(?:([^\s]+)[^\S\r\n]+)?(\d+)\r\n/i # MSG <subject> <sid> [reply-to] <#bytes>
		OK      = /\A\+OK\s*\r\n/i                                                  # +OK
		ERR     = /\A-ERR\s+('.+')?\r\n/i                                           # -ERR 'Something bad'
		PING    = /\APING\s*\r\n/i                                                  # PING
		PONG    = /\APONG\s*\r\n/i                                                  # PONG
		INFO    = /\AINFO\s+([^\r\n]+)\r\n/i                                        # INFO {"json_key":"json_value"}
		UNKNOWN = /\A(.*)/

		CR_LF = "\r\n"

		EMPTY_MESSAGE = ""

	end

end

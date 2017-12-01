require "socket"
require "openssl"

module NATS

	class Client
		class Connection
			alias AvailableSocketTypes = TCPSocket | OpenSSL::SSL::Socket

			BUFFER_SIZE = 65535_u16

			@socket : AvailableSocketTypes
			@buffer : Bytes = Bytes.new BUFFER_SIZE
			@uri : URI

			def initialize(@uri)
				@socket = TCPSocket.new @uri.host.not_nil!, @uri.port.not_nil!
			end

			def write(data : String) : Void
				@socket.write data.to_slice
			end

			def read_command : String?
				@socket.gets chomp: false
			end

			def read_data(bytesize : UInt32) : Bytes
				buffer = IO::Memory.new bytesize

				while bytesize > 0
					slice = bytesize > BUFFER_SIZE ? @buffer : Bytes.new( bytesize )
					read_amount = @socket.read slice
					buffer.write slice
					bytesize -= read_amount
				end

				@socket.gets # Trailing CR_LF

				buffer.to_slice
			end

			def disconnect : Void
				@socket.close
			end
		end
	end

end

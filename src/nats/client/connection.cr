require "socket"
require "openssl"

module NATS

	class Client
		class Connection
			alias AvailableSocketTypes = TCPSocket | OpenSSL::SSL::Socket

			BUFFER_SIZE = 65535_u16

			@socket : AvailableSocketTypes?
			@buffer : Bytes = Bytes.new BUFFER_SIZE

			def initialize(@uri : URI)
			end

			# TODO: Make it clean and DRY, and keep current object reusable
			def reinitialize(@uri : URI) : Void
				raise Exceptions::ConnectionInitializationException.new if @socket && !socket.closed?
			end

			def connect : Void
				@socket = TCPSocket.new @uri.host.not_nil!, @uri.port.not_nil!
			end

			def write(data : String) : Void
				socket.write data.to_slice
			end

			def read_command(raise_exception : Bool = false) : String?
				if data = socket.gets chomp: false
					raise Protocol::Exceptions::ErrCommandException.new data if raise_exception && data =~ Protocol::ERR
				else
					socket.close
				end

				data
			end

			def read_data(bytesize : UInt32) : Bytes
				buffer = IO::Memory.new bytesize

				while bytesize > 0
					slice = bytesize > BUFFER_SIZE ? @buffer : Bytes.new( bytesize )
					read_amount = socket.read slice
					buffer.write slice
					bytesize -= read_amount
				end

				socket.gets # Trailing CR_LF

				buffer.to_slice
			end

			def disconnect : Void
				socket.close
			end

			private def socket : AvailableSocketTypes
				@socket.not_nil!
			end
		end
	end

end

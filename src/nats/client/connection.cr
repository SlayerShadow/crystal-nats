require "socket"
require "openssl"

module NATS

	class Client
		class Connection
			BUFFER_SIZE = 65535_u16

			@socket : IO
			@buffer : Bytes = Bytes.new BUFFER_SIZE
			@uri : URI

			def initialize(@uri)
				@socket = TCPSocket.new @uri.host.not_nil!, @uri.port.not_nil!
			end

			def activate_tls(tls_config : OptionsTLSHash? = nil) : Void
				ssl_context = OpenSSL::SSL::Context::Client.new
				ssl_context.add_options OpenSSL::SSL::Options::NO_SSL_V2 | OpenSSL::SSL::Options::NO_SSL_V3 | OpenSSL::SSL::Options::NO_TLS_V1 | OpenSSL::SSL::Options::NO_TLS_V1_1

				if config = tls_config
					ssl_context.certificate_chain = config[ :cert_file ].as String if config[ :cert_file ]?
					ssl_context.private_key = config[ :cert_key_file ].as String if config[ :cert_key_file ]?
					ssl_context.ca_certificates = config[ :ca_cert_file ].as String if config[ :ca_cert_file ]?
					ssl_context.verify_mode = config[ :verify_peer ]? ? OpenSSL::SSL::VerifyMode::PEER : OpenSSL::SSL::VerifyMode::NONE
				end

				@socket = OpenSSL::SSL::Socket::Client.new @socket, ssl_context, true
			end

			def write(data : String) : Void
				# Because of sockets are always buffered, use flush after each sending
				# See https://github.com/crystal-lang/crystal/issues/5375
				# TODO: Add custom setting which will switch buffered state
				@socket.write data.to_slice
				@socket.flush
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

module NATS

	module Protocol

		module Exceptions

			class BaseException < Exception
			end

			class ConnectException < BaseException
			end

			class ErrCommandException < BaseException
				def initialize(command : String?)
					super "'-ERR' command received: #{ command }"
				end
			end

			class UnknownProtocolOperationException < ErrCommandException
				def initialize
					super "Unknown Protocol Operation"
				end
			end

			class AttemptedToConnectToRoutePortException < ErrCommandException
				def initialize
					super "Attempted To Connect To Route Port"
				end
			end

			class AuthorizationViolationException < ErrCommandException
				def initialize
					super "Authorization Violation"
				end
			end

			class AuthorizationTimeoutException < ErrCommandException
				def initialize
					super "Authorization Timeout"
				end
			end

			class InvalidClientProtocolException < ErrCommandException
				def initialize
					super "Invalid Client Protocol"
				end
			end

			class MaximumControlLineExceededException < ErrCommandException
				def initialize
					super "Maximum Control Line Exceeded"
				end
			end

			class ParserErrorException < ErrCommandException
				def initialize
					super "Parser Error"
				end
			end

			class SecureConnectionException < ErrCommandException
				def initialize
					super "Secure Connection - TLS Required"
				end
			end

			class StaleConnectionException < ErrCommandException
				def initialize
					super "Stale Connection"
				end
			end

			class MaximumConnectionsExceededException < ErrCommandException
				def initialize
					super "Maximum Connections Exceeded"
				end
			end

			class SlowConsumerException < ErrCommandException
				def initialize
					super "Slow Consumer"
				end
			end

			class MaximumPayloadViolationException < ErrCommandException
				def initialize
					super "Maximum Payload Violation"
				end
			end

			class InvalidSubjectException < ErrCommandException
				def initialize
					super "Invalid Subject"
				end
			end

			class PermissionsViolationForSubscriptionToSubjectException < ErrCommandException
				def initialize
					super "Permissions Violation for Subscription to <subject>"
				end
			end

			class PermissionsViolationForPublishToSubjectException < ErrCommandException
				def initialize
					super "Permissions Violation for Publish to <subject>"
				end
			end

		end

	end

end

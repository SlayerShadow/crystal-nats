module NATS

	DEFAULT_PORT = 4222_u16
	DEFAULT_URL  = "nats://localhost:#{ DEFAULT_PORT }"

	MAX_RECONNECT_ATTEMPTS = 10_u8
	RECONNECT_TIME_WAIT    = 2_u8

	CR_LF = Protocol::CR_LF

	EMPTY_MESSAGE = Protocol::EMPTY_MESSAGE

	STATUSES = {
		disconnected:  0_u8,
		connected:     1_u8,
		disconnecting: 1_u8,
		closed:        2_u8,
		reconnecting:  3_u8,
		connecting:    4_u8
	}

end

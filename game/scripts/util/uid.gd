class_name Uid
extends RefCounted
## Locally generated unique ids (architecture §10.3): 128 random bits, so two
## devices that never talked to each other do not collide when they meet.

const BYTE_COUNT := 16


## 32 lowercase hexadecimal characters.
static func generate() -> String:
	return Crypto.new().generate_random_bytes(BYTE_COUNT).hex_encode()

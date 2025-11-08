package envi

import os "core:os/os2"

main :: proc() {
	nextchar: [1]u8
	len, err := os.read(os.stdin, nextchar[:])
	for len == 1  && nextchar != 'q' {
		len, err = os.read(os.stdin, nextchar[:])
	}
}

package main

import (
	"encoding/binary"
	"flag"
	"fmt"
	"math/rand"
	"net"
)

func main() {

	// Parse args for the number of requested random IPv4 Addresses
	numIPv4AddrsPtr := flag.Int("count", 10000000, "How many addresses do you wish to generate?")
	flag.Parse()

	// Iterate
	for i := 0; i < *numIPv4AddrsPtr; i++ {
		ipByte := make([]byte, 4)
		binary.BigEndian.PutUint32(ipByte, rand.Uint32())
		ip := net.IP(ipByte)
		fmt.Println(ip.String())
	}

}

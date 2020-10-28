#!/usr/bin/env python3

import argparse
from random import getrandbits
import socket
import struct

parser = argparse.ArgumentParser()
parser.add_argument('-c', type=int, default=10000000)
args = parser.parse_args()

for _ in range(0, args.c):
    print(socket.inet_ntoa(struct.pack("!L", getrandbits(32))))

#!/usr/bin/python

import argparse, random, socket, struct

def long2ipv4addr(num):
    """
    Convert a long int to a dotted decimal IPv4 address
    """
    return socket.inet_ntoa(struct.pack("!L", num))

parser = argparse.ArgumentParser()
parser.add_argument('-c', type=int, default=10000000)
args = parser.parse_args()

# TODO: verify we have an integer in the input

for i in range(0, args.c):
    randnum = random.randint(0,2**32-1)
    print long2ipv4addr(randnum)

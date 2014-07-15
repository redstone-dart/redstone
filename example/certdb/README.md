This folder contains a certificate database used by RedStone for testing purposes only.

The password for the key database is "redstone".

It has been generated with the following commands:

```bash
$ certutil -N -d 'sql:./'
$ certutil -S -s "cn=RedStone" -n "Self signed certificate for RedStone" -x -t "C,C,C" -m 1000 - v120 -d "sql:./" -k rsa -g 2048
```

See [Secure Sockets and Servers with Dart 1.0](http://jamesslocum.com/post/70003236123) for more
information on how to setup a NSS key database and generate a self signed certificate.

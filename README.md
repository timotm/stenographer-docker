For example

```
docker run --net=host \
  --volume /var/steno:/var/lib/stenographer \
  --cap-add NET_ADMIN \
  --cap-add IPC_LOCK \
  timotm/stenographer \
  --interface enp0s3 \
  --indexbase /var/lib/stenograpapher/i \
  --packetsbase /var/lib/stenographer/p
```

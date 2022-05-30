# rocky-wheels

A simple Quart based Python web app that demonstrates building and publishing via Dagger.

```sh
# build image (if necessary) and save to local docker runtime with tag pythonapp:1
dagger do saveLocal --log-format plain

# run the app with local docker runtime
docker run -it --rm pythonapp:1

# build image (if necessary) and save to local image registry
dagger do publishApp --log-format plain
```

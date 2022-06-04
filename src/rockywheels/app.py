from quart import Quart

app = Quart("rocky-wheels")


@app.route("/")
async def hello():
    return "hello"


def main():
    app.run(host="0.0.0.0")


if __name__ == "__main__":
    main()
